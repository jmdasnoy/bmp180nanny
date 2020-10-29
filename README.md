# BMP180nanny by jmdasnoy 2020

## ESP32 NodeMCU Lua 5.1 handler for Bosch Sensortech BMP180 temperature and pressure sensor chip.

## Overview
This package provides a handler for the BMP180 chip.
It is based on information provided in the datasheet: BST-BMP180-DS000-09 rev 2.5 5 April 2013.

This handler ("nanny") will monitor i2c connectivity, check chip signature, load calibration coefficients and request measurement data from the chip.

The BMP180 does not produce recurrent measurements. Each measurement must be requested then read out.
In addition, the temperature is needed to calculate a precise pressure measurement.
The handler function `tick()` must be called on a regular basis, typically by a timer, to do this.
Four calls to `tick()` are needed to provide a temperature and pressure measurement update.
On startup, at least 3 calls to `tick()` are needed before the chip is ready to produce measurements.

## Application integration

The handler has 8 hooks for warning notification, error logging and data output.
The hooks are initially set to do nothing.
They can be adapted to suit application purposes.
The hooks are extensions to i2c callback functions and should be kept as short as possible.

Handler variables are available for accessing the latest read values, chip health indicator, chip name, oversampling settings, maximum acceptable number of i2c bus errors etc.

There are no helper/wrapper functions for doing this, as it is quite easy to directly access and modify the values directly.

## Considerations for i2c layout

The handler uses the ESP32 hardware i2c subsytems to allow asynchronous (non-blocking) operation.
It will not work with the software (bit-banging) i2c subsystem.

The BMP180 has a fixed i2c address.
Two chips can be used, one on each hardware i2c bus and each with its own handler.

## Using the package

The package exposes a single element, the constructor function `new( i2cid , oss )`.
The optional parameter i2cid indicates which i2c hardware subsystem should be used, i2c.HW0 or i2c.HW1. The default value is i2c.HW0
It is assumed that the i2c setup has been done elsewhere.
The optional parameter oss is the pressure oversampling setting, in the range [0-3]. The default value is 0.
The function returns a handler object as a table.

## Using the handler and example

For a complete example of handler setup possibilities, see the file chattybmp.lua in the utilities subfolder.
[Full example of handler setup possibilities](utilities/chattybmp.lua)

The handler function `tick()` must be called on a regular basis to produce measurements.







