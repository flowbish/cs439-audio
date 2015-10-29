#ifndef _TRANSMIT_H
#define _TRANSMIT_H

// should make these some kind of compile options
const int DURATION = 50;
const int PACKET_LEN = 10;

void transmit_init();
void send_byte(char);
void send_preamble(void);
void send_bit_high(void);
void send_bit_low(void);
void send_stop(void);

#endif
