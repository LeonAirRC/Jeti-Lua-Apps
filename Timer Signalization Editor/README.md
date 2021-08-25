## Timer Signalization Editor
### [Installation](https://github.com/LeonAirRC/Jeti-Lua-Apps#installation)
Changing the beeps, audio files and stick vibrations of a Timer Signalization usually takes a USB connection to edit the json files in the /Config folder.\
This app provides a simple interface to edit, add and delete those elements.\
\
![beepEdit1](https://user-images.githubusercontent.com/57962936/115938902-7897cd80-a49c-11eb-8f55-10bbaa8d1977.png)
![beepEdit2](https://user-images.githubusercontent.com/57962936/129450308-83d7218e-4070-4801-b8f5-0fb524820dd7.png)
![BeepEdit3](https://user-images.githubusercontent.com/57962936/129450314-3b2cf969-01bf-4bd0-b596-51b1bcc471eb.png)
\
Great [video](https://www.youtube.com/watch?v=xVmkDy7XcfY) by Harry Curzon\
\
**Select file**\
The Jeti transmitters have three discrete signalization files. Here you can choose which one you want to edit.\
\
**Editor**\
Each element has the attributes *time* [s] and *type*.
- type 1 is a beep and has the attributes *frequency* [Hz], *count* and *length* [ms].
- type 2 features an audio file

**Up/Down**\
Moves the focused element to the row above/below.\
\
**Add/Delete**\
Add a new element below the focused row or delete the focused element.\
\
**Vibration**\
Only visible on compatible transmitters. On this page the vibration profile for each timestemp can be edited.
