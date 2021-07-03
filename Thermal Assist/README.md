# Thermal Assistant
Inspired by a system used on manned gliders, this app helps to determine the optimal circling point in thermals.\
A periodic speech output tells the pilot the bearing and distance to the point where the center of the circle should be shifted to.\
Therefore a gps and a vario or altitude sensor are required.

### [Installation](https://github.com/LeonAirRC/Jeti-Lua-Apps#installation)

## How it works
The GPS position and the vario values are queried in regular intervals.\
Every point is displayed in the telemetry frame with the circle radius being proportional to the climb value if it is positive.\
At every time the flight path is shortened to contain a turn of at most 360°, thus it always represents the last circle.\
Based on the climb values along the path and the selected algorithm, the best point is determined.\
The announcement then contains the bearing and distance of the best point relative to the center point of the last circle as well as the climb rate at that point if available.

#### Switch
If no switch is selected, it is considered to be in on-position.\
When a switch is selected and in off-position, no more data points are added and the speech output is disabled.

#### Toggle search mode
Define a switch that enables the search mode. In this mode, the path is not shortened to one full circle and the announcement uses the current position as the reference point instead of the average position.
Algorithm 1 is used by default.

### Sensors
#### Reading interval
Interval at which gps and vario values are queried [ms].

#### Delay
Adds an artificial delay to compensate the delay most vario/altitude sensors have. This number is the amount of data points that the vario values are shifted 'back'. For example, if the reading interval is 0.8s and the vario has a delay of 1.5s, it is beneficial to set this number to 2.

### Algorithm
Currently there are three different algorithms to calculate the best point:
- Best subsequence
- Weighted vectors
- Weighted vectors with bias

For details on their usecases and how they work click [here](doc/algorithms.md).\
\
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist6.png" width=320/>
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist7.png" width=320/>\
Example: 'Weighted vectors' vs 'Best subsequence'

#### Switch
This switch can be used to change the algorithm in flight. If no switch is assigned, algorithm 2 is selected as default.

#### Minimum sequence length
The best point will not be calculated if the current number of gps points is lower than the minimum length.

#### Maximum sequence length
Used to prevent the path from getting very long if it does not contain a full 360° turn.

#### Best sequence length
To find the best spot on the path, the best-subsequence algorithm calculates the average climb rate for each subsequence of this length.\
Then the best point is the middle point of the best subsequence.

#### Expected climb rate
When checked, the app attempts to estimate the climb rate at the best point computed previously. This climb rate affects the size of the filled square in the telemetry frame and is also announced as part of the voice output.\
The expected climb rate is calculated as a weighted average, where the weight of each point is the inverse square of it's distance to the optimal point.

### Voice output
#### Announcement Interval
Interval at which the announcement occurs [s].

#### Announce bearing in degrees
When checked, the bearing to the optimal point is announced in degrees. Otherwise the included soundfiles are used to announce the direction, eg. "northwest".

#### Announce altitude
When checked and if an altitude sensor is selected in on the sensors page, the current altitude is announced at the end of each announcement.

### Telemetry Frame
#### Circle Radius
Radius of the circles in pixels per m/s climb rate.

## Screenshots
<p>
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist1.png" />
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist2.png" />
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist3.png" />
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist4.png" />
<img src="https://github.com/LeonAirRC/Jeti-Lua-Apps/raw/main/repository/doc/img/thlassist5.png" />
</p>

## Update Schedule
### v1.4
- adjustments based on real-world testing experiences
- add automatic algorithm selection
- use color display
- set delay in ms rather than points -> better precision

## Changelog
#### v1.2
- added delay
- minor fixes
#### v1.3
- added search mode
- added climb rate estimation
- added algorithm selection switch
- minor fixes
#### v1.4
- UI improvements
- forms reorganized
- altitude announcement added
- reduced memory usage
