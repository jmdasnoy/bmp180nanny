-- test conversion functions with datasheet example values
print( "starting BMP conversion tests")
--
bmp = require( "BMP180" )
--

bmptest = bmp.new( i2cid, 0 )
--
-- use values from datasheet
bmptest.AC1 = 408
bmptest.AC2 = -72
bmptest.AC3 = -14383
bmptest.AC4 = 32741
bmptest.AC5 = 32757
bmptest.AC6 = 23153
--
bmptest.B1 = 6190
bmptest.B2 = 4
--
bmptest.MB = -32768
bmptest.MC = -8711
bmptest.MD = 2868
--
ut = 27898
bmptest.oss = 0
--
up = 23843
--
bmptest:ut2t( ut )
bmptest:up2p( up )
print(" temperature should be 15, calculated value is: ", bmptest.T)
print(" pressure should be 699.64 calculated value is: ", bmptest.P)

