#include <WProgram.h>
#include <Audio.h>
#include "transmit.h"

// GUItool: begin automatically generated code
AudioSynthWaveform       synth1;          //xy=352,357
AudioOutputAnalog        dac1;           //xy=614,357
AudioConnection          patchCord1(synth1, dac1);
// GUItool: end automatically generated code

const int WAVEFORM = WAVEFORM_SINE;
const int FREQ_LOW = 7000;
const int FREQ_HIGH = 8000;

const int BIT_LOW = 0;
const int BIT_HIGH = 1;

// last bit sent, for the purpose of not pausing the audio in the middle of what
// should be a constant tone
int last_bit = -1;

void send_byte(char c) {
    int i;
    // send each bit of c, starting at the highest bit
    for (i = 7; i >= 0; i--) {
        int bit = (c>>i) & 1;
        if (bit) {
            send_bit_high();
        }
        else {
            send_bit_low();
        }
    }
}

// 8 pairs of low, high
inline void send_preamble() {
    send_byte('\x55');
    send_byte('\x55');
}

inline void send_bit_high() {
    // only need to send bit if last bit was different
    if (last_bit == BIT_LOW || last_bit == -1) {
        AudioNoInterrupts();
        synth1.begin(1.0, FREQ_HIGH, WAVEFORM);
        AudioInterrupts();
    }
    last_bit = BIT_HIGH;
    delay(DURATION);
}

inline void send_bit_low() {
    // only need to send bit if last bit was different
    if (last_bit == BIT_HIGH || last_bit == -1) {
        AudioNoInterrupts();
        synth1.begin(1.0, FREQ_LOW, WAVEFORM);
        AudioInterrupts();
    }
    last_bit = BIT_LOW;
    delay(DURATION);
}

inline void send_stop() {
    // disable audio output
    AudioNoInterrupts();
    synth1.begin(0.0, FREQ_HIGH, WAVEFORM);
    AudioInterrupts();

    // reset last bit played
    last_bit = -1;
}
