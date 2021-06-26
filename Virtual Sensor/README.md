# Vitual Sensor
### [Installation](https://github.com/LeonAirRC/Jeti-Lua-Apps#installation)
Calculates virtual telemetry values that can be composed of mathematical and boolean operations.\
The numeric inputs can be constants, telemetry values, proportional controls, switches, trainer inputs, ppm inputs and servo outputs.\
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
![virtsens1](https://user-images.githubusercontent.com/57962936/115939243-d24cc780-a49d-11eb-8d96-382a423f099a.png)
![virtsens2](https://user-images.githubusercontent.com/57962936/115939245-d2e55e00-a49d-11eb-8c6c-05a84021d94b.png)
![virtsens3](https://user-images.githubusercontent.com/57962936/115939247-d37df480-a49d-11eb-9186-716df63b23ee.png)

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
