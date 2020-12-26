# Traffic Signal Simulator

### Description –
This Traffic Signal project simulates a normal traffic light sequence which can be interrupted by any wanting pedestrians trying to cross the street. Its normal mode simulates a standard busy road with it’s (Green, Yellow, Red) lights having time intervals of (6, 2, 4) seconds respectively. The interrupt cycle, also known as the fast mode, allows pedestrians to push a button to speed up the current normal mode cycle of (6, 2, 4) seconds to (4, 2, 4) to decrease the wait time on the green light. However, if the pedestrian were to push the button when the yellow or the red light are active it would ignore their request and continue the normal cycle.

### Components –
•	1 - Arduino Uno R3 Microcontroller

•	1 - 830 Tie-Points Breadboard

•	1 – Button

•	3 – LED (Green, Yellow, Red)

•	3 – 300 Ohm Resistors

•	9 – Breadboard Jumper Wires

### Programming Concepts –
Key programming concepts utilized in this project:

•	AVR Interrupts (OC1Aaddr – Timer/Counter1 Compare Match A and INT1addr – External Interrupt Request) to handle normal mode and fast mode to avoid altercation between individual arrays.

•	Multiple instances of Branch instructions, compare instructions, and looping throughout the project to handle which LED will be toggled and at which specified time.

•	I/O port, I/O bit manipulation to toggle specified LED’s on/off.

•	Arithmetic logic to add with carry to get correct index of array.

•	AVR Timer1 to loop every second until counter matches array index.

Additional Concepts used

•	AVR directives to define constants.

•	High() and Low() functions to obtain a 16 bit value.

### Electric circuit diagram –

![Electric Circuit Diagram](Pictures/Electric%circuit%diagram.PNG)
