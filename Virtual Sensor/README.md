# Vitual Sensor
Calculates a virtual telemetry value and registers virtual log variables.\
The numeric inputs can be constants, telemetry values, proportional controls, switches, trainer inputs, ppm inputs and servo outputs.\
Numeric values are processed in a tree of mathematical operation that take either one or two operators, eg ADD, MIN, SQRT, SIN, ABS.\
\
Although constants can only be integers, floating point constants can be created with DIV elements:\
3.1416 = DIV 31416 10000\
\
**F4** select the sensor value that is displayed in the telemetry frame

### Output specification
| Input | Output |
| :---- | :----: |
| **Sensor** ||
| &nbsp;&nbsp;&nbsp;&nbsp;Sensor not selected | nil |
| &nbsp;&nbsp;&nbsp;&nbsp;Sensor invalid | nil |
| **Input** | **[-1;1]** |
| &nbsp;&nbsp;&nbsp;&nbsp;Input not selected | nil |
| **ADD,SUB,MUL,DIV** ||
| &nbsp;&nbsp;&nbsp;&nbsp;1 or 2 parameters *nil* | nil |
| &nbsp;&nbsp;&nbsp;&nbsp;**DIV** parameter 1 valid,<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;parameter 2 is 0 | nil |
| **MIN,MAX** ||
| &nbsp;&nbsp;&nbsp;&nbsp;both parameters *nil* | nil |
| &nbsp;&nbsp;&nbsp;&nbsp;parameter 1 *nil* | parameter 2 |
| &nbsp;&nbsp;&nbsp;&nbsp;parameter 2 *nil* | parameter 1 |
| **ABS,ROUND,FLOOR,CEIL**||
| &nbsp;&nbsp;&nbsp;&nbsp;parameter *nil* | nil |
| **SQRT** ||
| &nbsp;&nbsp;&nbsp;&nbsp;parameter *nil* | nil |
| &nbsp;&nbsp;&nbsp;&nbsp;parameter < 0 | nil |
| **SIN,COS,TAN<br>ASIN,ACOS,ATAN** | **unit: °** |
| &nbsp;&nbsp;&nbsp;&nbsp;parameter *nil* | nil |
