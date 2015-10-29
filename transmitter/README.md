Transmitter
========

Features
--------

The transmitter supports reading a bytestream over its USB serial interface. The
bytes are automatically formatted into packet and broadcast via the attached speaker.
Currently the transmitter employs BFSK modulation with Manhattan encoding to ensure
synchronization between transmitter and receiver.


Hardware
--------

The transmitter is developed for a Teensy 3.1 microcontroller. The reason for this
specific hardware is both comfort in its environment and the fact that the board come
with a builtin DAC, making audio systhesis very simple.

The analog output of the Teensy is connected to a simple amplifying circuit that
outputs to a large surface transducer. 
