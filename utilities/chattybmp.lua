-- jmdasnoy scripsit 2019 copyright CC BY-SA
-- NodeMCU ESP32 example use of lua BMP180nanny handler package for Bosch Sensortech BMP-180 Digital pressure and temperature sensor
-- for standalone use, with output to stdout console
-- setup BMP180 with a chatty nanny
print( "setting up chattybmp")
-- setup i2C
local i2cid=i2c.HW1  -- hardware i2c, must use queuing and callbacks
local pinSDA=23 -- Huzzah32 silkscreen
-- local pinSDA=21 -- Expressif default
local pinSCL=22 -- according to Huzzah32 silk screen
--
local i2cspeed=30000
--
local i2cstretch=5 -- allow more than default clock stretching
--
print( "chattybmp: i2c.setup returned: ", i2c.setup( i2cid, pinSDA, pinSCL, i2cspeed, i2cstretch ))
-- construct a new handler object
local chattybmp = require( "BMP180nanny" ).new( i2cid, 0 )
package.loaded.BMP180nanny = nil
-- chatty error loggers
local function badi2c( self )
  print( (time.get() .. self.name .." no response from i2c bus: %d at address: 0x%X ") : format ( self.i2cinterface , self.i2caddress))
end
--
local function badchipsignature( self, data )
    print( "i2c device on bus: ", self.i2cinterface, " at address: ", self.i2caddress, "does not have the expected signature for BMP180")
    print( "expected chip signature", self.value.CHIP_ID )
    print( "received chip signature", data:byte( 1 ) )
end
--
local function badcalib( self  )
  print( self.name .. " One or more invalid calibration values read from chip" )
end
--
local function warntemperature( self  )
  print( self.name ..  " BMP180 still busy with temperature read, please wait" )
end
--
local function warnpressure( self  )
  print( self.name .. " BMP180 still busy with pressure read, please wait" )
end
--
local function badfatal( self )
  print( self.name .. " handler is now disabled" )
-- chatty data output functions
local function showtemperature( self ) print( time.get() , self.name .. " Temperature °C: " , self.T ) end
local function showpressure( self ) print( time.get() , self.name .. " Pressure hPa: " , self.P ) end
-- 
end
-- adapt settings as needed
  chattybmp.name = "chattybmp180"  -- override default chip name
  chattybmp.oss = 3 -- override default oversampling mode, use highest precision
  chattybmp.i2c_err_max = 10 -- override default maximum number of cumulative i2c read errors
-- tie in the error loggers
  chattybmp.i2c_err_log = badi2c
  chattybmp.chip_err_log = badchipsignature
  chattybmp.calib_err_log = badcalib
  chattybmp.fatal_err_log = badfatal
  chattybmp.temperature_wait_log = warntemperature
  chattybmp.pressure_wait_log = warnpressure
-- tie in data update functions
  chattybmp.temperature_update = showtemperature
  chattybmp.pressure_update = showpressure
-- 
print( "starting chattybmp operations" )
-- set up a timer to run this
bmptimer = tmr.create()
-- function for fast setup
local function fastbmp( timer )
  print("running fast BMP180 setup")
  print( "chattybmp.health: " , chattybmp.health )
  if chattybmp.health ~= "RUN" then
    chattybmp:tick()
  else
    print( "changing to slow BMP180 timer for data streaming" )
    timer:unregister( ) -- stop fast timer and deregister fast callback
    timer:register( 30000, tmr.ALARM_AUTO, function() chattybmp:tick( ) end )
    timer:start()
  end
end
-- start timer in fast mode for quick setup
bmptimer:register( 1000, tmr.ALARM_AUTO, fastbmp )
print( "starting  chattybmp on fast timer" )
bmptimer:start( )
--
print( "stop the timer tick by bmptimer:stop()" )

