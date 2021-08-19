# Vitual Sensor
### [Installation](https://github.com/LeonAirRC/Jeti-Lua-Apps#installation)
Calculates virtual telemetry values that can be composed of mathematical and boolean operations.\
The numeric inputs can be constants, telemetry values, proportional controls and switches.\
Numeric values are processed in a tree of mathematical operation that take either one or two operators, eg ADD, MIN, SQRT, SIN, ABS.\
\
Although constants can only be integers, floating point constants can be created with DIV elements:\
3.1416 = DIV 31416 10000\
\
**F(4):** select the sensor value that is displayed in the telemetry frame

## Example
This sensor calculates the glide ratio:\
\
<img src="https://user-images.githubusercontent.com/57962936/115624339-c70d6680-a2fa-11eb-9853-4edf9fe20384.png" width=500/>

## Screenshots
![virtsens1](https://raw.githubusercontent.com/LeonAirRC/Jeti-Lua-Apps/main/repository/doc/img/virtsens2.png)
![virtsens2](https://raw.githubusercontent.com/LeonAirRC/Jeti-Lua-Apps/main/repository/doc/img/virtsens3.png)
![virtsens3](https://raw.githubusercontent.com/LeonAirRC/Jeti-Lua-Apps/main/repository/doc/img/virtsens1.png)

### Control
Each sensor can be assigned to one of the ten virtual controls, C1 - C10. These can be assigned wherever a control(-stick) can be assigned.

### Integral
Integrates the parameter over time. All integrals can be reset with the integral reset switch.

## Changelog
#### v1.1
- added voice annoucements
- added control output
- efficiency improvements
#### v1.2
- added boolean operators
- fixed control assignment on initialization
#### v1.3
- removed log variables and voice output to reduce memory usage
- added integral node
#### v1.4
- sensors with parameters use other virtual sensors as inputs, removed child node architecture
- new telemetry design: multiple sensors can be selected to be displayed in a frame
- significant efficiency improvements
