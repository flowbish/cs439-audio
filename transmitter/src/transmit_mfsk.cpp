#include <WProgram.h>
#include <Audio.h>
#include "transmit.h"

#ifndef ENCODING
    #error You must define a value for ENCODING
#endif

#if ENCODING == MFSK

// GUItool: begin automatically generated code
AudioSynthWaveform       synth1;          //xy=352,357
AudioOutputAnalog        dac1;           //xy=614,357
AudioConnection          patchCord1(synth1, dac1);
// GUItool: end automatically generated code

// each symbol carries 6 bits
typedef uint8_t symbol;

const int WAVEFORM = WAVEFORM_SINE;
const int FREQS[] = {6000, 6200, 6400, 6600, 6800, 7000, 7200, 7400, 7600};
const size_t NFREQS = 9;
const size_t SYMBOL_MAX = NFREQS * NFREQS - NFREQS - 1;
const size_t bits_per_transmission = 6;
const size_t transmission_mask = (2 << bits_per_transmission) - 1;

// last freq sent, for the purpose of not pausing the audio in the middle of what
// should be a constant tone
int last_freq = -1;
uint32_t pending = 0;
uint32_t npending = 0;

// returns the (0,1) frequency for specified symbol
inline int transition_freq(symbol s, int i) {
    // ensure symbol is in range
    if (s > SYMBOL_MAX)
        return -1;

    // 6 bit symbol, in range [0x00, 0x3f]
    // also 8 control signals [0x40, 0x47]
    if (i == 0) {
        // first frequency of transition
        return FREQS[s / (NFREQS-1)];
    }
    else if (i == 1) {
        // second frequency of transition
        // ensure nothing falls on the diagonals
        // TODO: document this math
        int diagonal = s / (NFREQS-1);
        int carry = s % (NFREQS-1);
        return FREQS[carry + (carry < diagonal ? 0 : 1)];
    }
    else return -1;
}

inline void send_freq (int freq) {
    // only need to send bit if last freq was different
    if (last_freq != freq || last_freq == -1) {
        AudioNoInterrupts();
        synth1.begin(1.0, freq, WAVEFORM);
        AudioInterrupts();
    }
    last_freq = freq;
    delay(DURATION);
}

void append_byte(char c) {
    pending = pending << 8;
    pending |= c;
    npending += 8;
}

void send_byte (char c) {
    append_byte(c);

    while (npending >= bits_per_transmission) {
        // extract the top bits_per_transmission bits from pending
        int shift = npending - bits_per_transmission;
        symbol send = (pending >> shift) & transmission_mask;

        // send each 6 bits of pending in one transition
        int f0 = transition_freq(send, 0);
        int f1 = transition_freq(send, 1);
        send_freq(f0);
        send_freq(f1);

        // update pending bits
        pending >>= shift;
        npending -= bits_per_transmission;
    }
}

// 8 pairs of low, high
void send_preamble () {
    symbol PREAMBLE[] = {0x3, 0xc, 0x15, 0x1e, 0x27, 0x28, 0x31, 0x3a};
    for (int i = 0; i < 8; i++) {
        // send each 6 bits of pending in one symbol (transition)
        symbol send = PREAMBLE[i];
        int f0 = transition_freq(send, 0);
        int f1 = transition_freq(send, 1);
        send_freq(f0);
        send_freq(f1);
    }
}

void send_start () {
    // reset last freq played
    last_freq = -1;
    pending = 0;
    npending = 0;
}

void send_stop () {
    // disable audio output
    AudioNoInterrupts();
    synth1.begin(0.0, 0, WAVEFORM);
    AudioInterrupts();
}

#endif
