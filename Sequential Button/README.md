# Sequential Button
### [Installation](https://github.com/LeonAirRC/Jeti-Lua-Apps#installation)
<p>
<img src="https://user-images.githubusercontent.com/57962936/120362788-c01b4000-c30b-11eb-8da5-41d6ad2aeefa.png" width=300/>
<img src="https://user-images.githubusercontent.com/57962936/120362791-c0b3d680-c30b-11eb-8623-7c84008b37dd.png" width=300/>
</p>

Define a sequence of states (deflections) and increase/decrease the current state sequentially.\
A virtual control is used as the ouput.

#### Switches
The switches used to go to the next/previous state.

#### Control
Select one out of the ten virtual controls as the output.

#### Delay
Set the control's delay in ms.

#### Smooth
Uses a lowpass filtering algorithm instead of linear interpolation when checked.

#### Endless
When checked, the state can jump to the other end of the sequence. This applies to both directions.

#### States
The list of states. The deflection for each state can be set.\
The current state is displayed in bold font.\
The initial state (on application initialization) can be selected with the button **F(3)** and is indicated by the (init) phrase.\
The number of states has to be between 1 and 20.
