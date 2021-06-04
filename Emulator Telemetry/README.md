# Emulator Telemetry

This app overrides the transmitter's functions for telemetry data retrieval.\
The list of emulated sensors can be defined in the <i>/EmulatedTelemetry/sensors.json</i> file.\
The current value of each sensor can be controlled by one of the inputs, eg. "P1" and "SA".\

### Warning
Only use this app on the emulator! It overrides some functions of the Lua api which can lead to unexpected effects on other apps.

### Installation
Move the <i>emutelem.lua</i> file and the <i>EmulatedTelemetry</i> folder into the emulator's Apps folder.\
\
\
In <a href="https://github.com/LeonAirRC/Jeti-Lua-Apps/tree/main/Emulator%20Telemetry/EmulatedTelemetry/sensors.json">this</a> example there are three sensors:\
GPS Sensor:
- Param 1: Latitude, ranging from 0 to 0.001°N, controlled by P4
- Param 2: Longitude, ranging from 0 to 0.001°E, controlled by P3

Altitude Sensor:
- Param 1: Altitude, ranging from 0 to 10m, controlled by P5
- Param 2: Vario, ranging from -1 to 1m/s, controlled by P6

Time/Date Sensor:
- Param 1: Time, ranging from 0 to 10000s (0:00:00 to 2:46:40), controlled by P1
- Param 2: Date, ranging from 0 to 1000d (Jan 1, 2000 to Sep 28, 2002), controlled by P2

\
\
The range for gps sensors is specified in degrees, the time in seconds and the date is specified in days since Jan 1, 2000.\
Leap years are **not** respected.
