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

#### Reading interval
Interval at which gps and vario values are queried [ms].

#### Announcement Interval
Interval at which the announcement occurs [s].

#### Toggle search mode
Define a switch that enables the search mode. In this mode, the path is not shortened to one full circle and the announcement uses the current position as the reference point instead of the average position.

#### Always use algorithm 1 in search mode
When this is checked and search mode is active, the app will always use the best-subsequence algorithm which is the obvious choice for searching thermals.

#### Delay
Adds an artificial delay to compensate the delay most vario/altitude sensors have. This number is the amount of data points that the vario values are shifted 'back'. For example, if the reading interval is 0.8s and the vario has a delay of 1.5s, it is beneficial to set this number to 2.

### Algorithm
Currently there are three different algorithms to calculate the best point:
- Best subsequence
- Weighted vectors
- Weighted vectors with bias

For details on their usecases and how they work click [here](doc/algorithms.md).\
\
<img src="https://user-images.githubusercontent.com/57962936/115938774-0a530b00-a49c-11eb-8f15-e7ce81d31ad9.png" width=320/>
<img src="https://user-images.githubusercontent.com/57962936/115938776-0aeba180-a49c-11eb-8280-065e14868b05.png" width=320/>\
Example: 'Weighted vectors' vs 'Best subsequence'

#### Switch
This switch can be used to change the algorithm in flight. If no switch is assigned, the algorithm can be chosen manually.\
Due to a bug in the Lua-api the app cannot detect if this switch was deleted/unassigned. Therefore the button **F(1): Clr** has to be used to clear the switch and allow manual algorithm selection. (The same applies to the [zoom](#zoom-switch).)

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

### Telemetry Frame
#### Zoom switch
The pilot can define a zoom switch for the 'map' of gps points.\
If the switch is not set or in -1 position, the autozoom is enabled.\
Autozoom is the highest zoom level at which all points are on the screen.\
Due to a bug in the Lua-api the app cannot detect if the zoom-switch was deleted/unassigned. Therefore the button **F(1): Clr** has to be used to clear the zoom switch and enable autozoom.

#### Circle Radius
Radius of the circles in pixels per m/s climb rate.

#### Zoom range
Range of the zoom levels reachable with the zoom switch.

## Screenshots
![thlassist1](https://user-images.githubusercontent.com/57962936/115938866-54d48780-a49c-11eb-91b7-37d76e940edf.png)
![thlassist2](https://user-images.githubusercontent.com/57962936/115938868-54d48780-a49c-11eb-8dfe-5ff7394d361c.png)
![thlassist3](https://user-images.githubusercontent.com/57962936/115938869-556d1e00-a49c-11eb-8d86-7a65c01fd653.png)
![thlassist4](https://user-images.githubusercontent.com/57962936/115938870-5605b480-a49c-11eb-9556-95f6e681dc5b.png)

## Update Schedule
### v1.4
- adjustments based on real-world testing experiences
- add automatic algorithm selection
- UI improvements
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
