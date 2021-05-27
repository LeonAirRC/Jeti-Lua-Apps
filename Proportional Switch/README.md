# Proportional Switch
Registers up to ten new controls whose state can be moved up and down with two switches.\
Example: The flaps slowly move up as long as the up-switch is triggered and move down if the down-switch is triggered.\
The input switches can also be proportional which allows even more precise controls.\
\
Combined with a [virtual sensor]("https://github.com/LeonAirRC/Jeti-Lua-Apps/tree/main/Virtual%20Sensor)
this can also act as an **integral** over any control or telemetry.

### Neutral point
Describes the input value for which the output does not change. Usually it is -1, but can be 0 if one switch is used to control both directions.\
When the neutral point is 0, both inputs can control both directions. Hence it is useful when the input(s) should be integrated.

### Delay
The time it takes the output value to change by 1. Defines the movement speed.\
\
![propswitch](https://user-images.githubusercontent.com/57962936/118042978-12a0b680-b375-11eb-90f7-540acb66c801.png)
![propswitch1](https://user-images.githubusercontent.com/57962936/118042980-13394d00-b375-11eb-8ca1-20c27e2cb575.png)
