#ifndef _TRANSMIT_H
#define _TRANSMIT_H

#define VANILLA 1000
#define MANCHESTER 2000
#define MFSK 3000

#ifndef ENCODING
    #error You must define a value for ENCODING
#endif

void send_start(void);
void send_byte(char);
void send_preamble(void);
void send_stop(void);
void set_mtu(unsigned int);
unsigned int get_mtu(void);
void set_duration(unsigned int);
unsigned int get_duration(void);

#endif
