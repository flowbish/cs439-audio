#!/bin/bash

TTY=/dev/ttyACM0
BAUD=115200
INFILE=teensy.in
OUTFILE=teensy.out


stty -F $TTY $BAUD cs8 cread clocal
tee $TTY < $INFILE &
tee $OUTFILE < $TTY &
