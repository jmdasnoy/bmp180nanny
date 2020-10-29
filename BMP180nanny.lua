-- jmdasnoy scripsit 2019 copyright CC BY-SA
-- NodeMCU ESP32 lua handler for Bosch Sensortech BMP-180 Digital pressure and temperature sensor
-- datasheet version: BST-BMP180-DS000-09 rev 2.5 5 April 2013
--
-- populate table with register addresses, reset/read values, symbolic settings, expected values ie settings
local function populatetable()
  local bmp={}
-- i2c particulars and defaults
  bmp.i2cinterface =i2c.HW0  -- only works with hardware i2c subsystems
  bmp.i2caddress = 0x77  -- fixed
-- 
  bmp.register = {} -- register hardware addresses
  bmp.expect = {} -- expected value from register
  bmp.set = {} -- special values for register
--
  bmp.register.CHIP_ID = 0xD0
  bmp.expect.CHIP_ID = 0x55
--
  bmp.register.AC1_MSB = 0xAA
  bmp.register.CTRL_MEAS = 0xF4
--
  bmp.register.softreset = 0xE0
  bmp.set.softreset = 0xB6
--
  bmp.oss = 0 -- default oversampling mode, ultra low power, range [0-3]
  bmp.i2c_err_max = 5 -- maximum number of cumulative i2c read errors
--
  bmp.name = "BMP180" -- default device name
--
  bmp.health = "STOP" -- default state of health, other values are INIT , RUN or ERROR
--
  return bmp
end
--
local function tick( self ) -- execute function acccording to FSM state
  self:state()
end
-- functions for FSM states
--
-- forward declarations of state functions
local checkchip
local resetchip
local getcalib
local requestUT
local readUT
local requestUP
local readUP

-- forward declarations of functions called from states
local readbytes
local writebytes
local cleancalib
local ut2t
local up2p
local fsm_start
local fsm_disable
local i2c_ok
local i2c_err
--
checkchip = function( self ) -- state 0: attempt to get a response from the bus/address and compare with expected signature
  readbytes( self.i2cinterface, self.i2caddress, self.register.CHIP_ID, 1,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        if data:byte( 1 ) == self.expect.CHIP_ID then
          self.state = resetchip
          self.health = "INIT"
        else
          self:chip_err_log( data )
          fsm_disable( self )
        end
      end
    end
  )
end
--
resetchip = function ( self )  -- state 1: soft chip reset
  writebytes( self.i2cinterface, self.i2caddress, self.register.softreset, self.set.softreset ,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        self.state = getcalib
      end
    end
  )
end
--
getcalib = function( self )  -- state 2: get EEPROM calibration values 11*16bits
  readbytes( self.i2cinterface, self.i2caddress, self.register.AC1_MSB, 22,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        self.calib = true
-- calibration values are signed except AC4, AC5 , AC6
        self.AC1 = cleancalib( self, data, 1)
        self.AC2 = cleancalib( self, data, 3)
        self.AC3 = cleancalib( self, data, 5)
-- AC4, AC5 , AC6 are unsigned
        self.AC4 = ucleancalib( self, data, 7)
        self.AC5 = ucleancalib( self, data, 9)
        self.AC6 = ucleancalib( self, data, 11)
-- rest are signed values
        self.B1 =  cleancalib( self, data, 13)
        self.B2 =  cleancalib( self, data, 15)
        self.MB =  cleancalib( self, data, 17)
        self.MC =  cleancalib( self, data, 19)
        self.MD =  cleancalib( self, data, 21)
        if self.calib then
          self.state = requestUT
          self.health = "RUN"
        else
          self:calib_err_log( )
          fsm_disable( self )
        end
      end
    end
  )
end
--
requestUT = function ( self )  -- state 3: request temperature measure
  writebytes( self.i2cinterface, self.i2caddress, self.register.CTRL_MEAS, 0x2E,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        self.state = readUT
      end
    end
  )
end
--
readUT = function ( self )  -- state 4: read temperature
  readbytes( self.i2cinterface, self.i2caddress, self.register.CTRL_MEAS, 4 ,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        if bit.isclear( data:byte( 1 ), 5 ) then
          local ut = bit.lshift( data:byte( 3 ) , 8 ) + data:byte( 4 )
          ut2t( self , ut )
          self:temperature_update( )
          self.state = requestUP
        else
          self:temperature_wait_log( )
        end
      end
    end
  )
end
--
requestUP = function ( self )  -- state 5: request pressure read
  writebytes( self.i2cinterface, self.i2caddress, self.register.CTRL_MEAS, self.pressureread,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        self.state = readUP
      end
    end
  )
end
readUP = function ( self )  -- state 6: read pressure
  readbytes( self.i2cinterface, self.i2caddress, self.register.CTRL_MEAS, 5 ,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        if bit.isclear( data:byte( 1 ), 5 ) then
          local up = bit.lshift( data:byte( 3 ) , 16 ) + bit.lshift( data:byte( 4 ) , 8) + data:byte( 5 )
          up = bit.rshift( up, 8-self.oss )
          up2p( self , up )
          self:pressure_update( )
          self.state = requestUT
        else
          self:pressure_wait_log( )
        end
      end
    end
  )
end
--
readbytes = function( interface, address, register, nbytes, callback) -- block read multiple bytes from registers and execute callback when done
  i2c.start( interface )
  i2c.address( interface, address, i2c.TRANSMITTER, true )
  i2c.write( interface, register, true )
  i2c.start( interface )
  i2c.address( interface, address, i2c.RECEIVER, true)
  i2c.read( interface,nbytes )
  i2c.stop( interface)
  i2c.transfer( interface,callback )
end
--
writebytes = function( interface, address, register, value, callback) -- write value(s) to register and execute callback when done
  i2c.start( interface )
  i2c.address( interface , address, i2c.TRANSMITTER, true )
  i2c.write( interface, register, value, true ) -- value may be multiple bytes 
  i2c.stop( interface )
  i2c.transfer( interface,callback )
  end
--
cleancalib = function( self, data, index)
  local val = ( data:byte( index + 1 ) + bit.lshift( data:byte( index ), 8 ) )
  if val == 0 or val == 0xFFFF then
    self.calib = false
    return 0
  elseif val>32767 then
    return (val-65536)
  else
    return val
  end
end
--
ucleancalib = function( self, data, index)
  local val = ( data:byte( index + 1 ) + bit.lshift( data:byte( index ), 8 ) )
  if val == 0 or val == 0xFFFF then
    self.calib = false
    return 0
  else
    return val
  end
end
-- conversion functions
ut2t = function( self , ut )
  local x1 = bit.arshift( ((ut - self.AC6) * self.AC5 ) , 15)
local x2 = bit.lshift( self.MC, 11) / (x1 + self.MD)
-- round to integer after division
  x2 = x2>=0 and math.floor(x2+0.5) or math.ceil(x2-0.5)
  local b5 = x1 + x2
  self.B5 = b5
  self.T = bit.arshift( ( b5 + 8), 4) / 10
end
--
up2p = function( self, up )
  local b6 = self.B5-4000
  local x1 = bit.arshift( self.B2 * b6 * b6, 23 )
  local x2 = bit.arshift( self.AC2 * b6, 11)
  local x3 = x1 + x2
  local b3 = bit.arshift( (bit.lshift( self.AC1 * 4 + x3, self.oss) + 2) , 2)
  x1 = bit.arshift( self.AC3 * b6, 13)
  x2 = bit.arshift( self.B1 * b6 * b6 / 4096 , 16)
  x3 = bit.arshift( x1 + x2 + 2 , 2)
  local b4 = bit.arshift( self.AC4 * ( x3 + 32768 ), 15)
  local b7 = ( up - b3 ) * bit.arshift( 50000 , self.oss )
  local p = 2 * b7 / b4
  p = p>=0 and math.floor(p+0.5) or math.ceil(p-0.5)
  x1 = bit.arshift( p , 8)
  x1 = x1 * x1
  x1 = bit.arshift( x1 * 3038 , 16)
  x2 = bit.arshift( -7357 * p , 16 )
  self.P = ( p + bit.arshift(( x1 + x2 + 3791) , 4 ) ) / 100
end
-- FSM control
fsm_start = function( self )
  self.i2c_err_count = 0
  self.state = checkchip
end
--
fsm_disable = function( self )
  self.state = function() end
  self:fatal_err_log( )
  self.health = "ERROR"
end
-- error handlers
i2c_ok = function( self )
  if self.i2c_err_count > 0 then
    self.i2c_err_count = self.i2c_err_count - 1
  end
end
--
i2c_err = function( self )
  self:i2c_err_log()
  if self.i2c_err_count < self.i2c_err_max then
    self.i2c_err_count = self.i2c_err_count + 1
  else
    fsm_disable( self )
  end
end
--
local function new( interface , oss )
  local bmp = populatetable()
  bmp.i2cinterface = interface or bmp.i2cinterface
--
  bmp.oss = oss or bmp.oss
  bmp.oss = bit.band( bmp.oss , 3) -- keep in range [0-3]
  bmp.pressureread = 0x34 + bit.lshift( bmp.oss, 6)
-- error loggers and data available hooks are initially set to do nothing 
  local function donothing( ) end
  bmp.i2c_err_log = donothing
  bmp.chip_err_log = donothing
  bmp.calib_err_log = donothing
  bmp.fatal_err_log = donothing
  bmp.temperature_wait_log = donothing
  bmp.pressure_wait_log = donothing
-- default data update hooks
  bmp.temperature_update = donothing
  bmp.pressure_update = donothing
-- initial FSM state
  fsm_start( bmp )
-- exported functions
  bmp.tick = tick
  bmp.reset = fsm_start
--[[ export the two conversion functions only for testing purposes
  bmp.ut2t = ut2t
  bmp.up2p = up2p
--]]
--
  return bmp
end
--
return { new = new }
