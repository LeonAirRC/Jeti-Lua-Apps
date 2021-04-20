# Thermal Assistant
Inspired by a system used on manned gliders, this app helps to determine the optimal circling point in thermals.\
A periodic speech output tells the pilot the bearing and distance to the point where the center of the circle should be shifted to.\
Therefore a gps and a vario or altitude sensor are required.
## How it works
The GPS position and the vario values are queried at regular intervals.\
Every point is displayed in the telemetry frame with the circle radius being proportional to the climb value if it is positive.\
At every time the flight path is shortened to contain a turn of at most 360°, thus it always represents the last circle.\
Based on the climb values along the path and the selected algorithm, the best point is determined.\
The announcement then contains the bearing and distance of the best point relative to the center point of the last circle as well as the climb rate at that point if available.

#### Switch
If no switch is selected, it is considered to be in on-position.\
When a switch is selected and in off-position, no more data points are added and the speech output is disabled.

#### Reading interval
Interval at which gps and vario values are queried [ms].

#### Interval
Interval at which the announcement occur [s].

### Algorithm
Currently there are three different algorithms to calculate the best point:
- Best subsequence
- Weighted vectors
- Weighted vectors with bias

For details on their usecases and how they work click [here](doc/algorithms.md).

#### Minimum sequence length
The best point will not be calculated if the current number of gps points is lower than the minimum length.

#### Maximum sequence length
Used to prevent the path from getting very long if it does not contain a full 360° turn.

#### Best sequence length
To find the best spot on the path, the app calculates the average climb rate for each subsequence of this length.\
Then the best point is the middle point of the best subsequence.

### Telemetry Frame
#### Zoom switch
The pilot can define a zoom switch for the 'map' of gps points.\
If the switch is not set or in -1 position, the autozoom is enabled.\
Autozoom is the highest zoom level at which all points are on the screen.

#### Circle Radius
Radius of the circles in pixels per m/s climb rate.

#### Zoom range
Range of the zoom levels reachable with the zoom switch.
