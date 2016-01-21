#ifndef _TRANSMIT_H
#define _TRANSMIT_H

#define VANILLA 1000
#define MANCHESTER 2000
#define MFSK 3000

#ifndef ENCODING
    #error You must define a value for ENCODING
#endif

#if ENCODING == VANILLA
    #define DURATION 50
    #define PACKET_LEN 10
#elif ENCODING == MANCHESTER
    #define DURATION 50
    #define PACKET_LEN 10
#elif ENCODING == MFSK
    #define DURATION 10
    #define PACKET_LEN 32
#endif

void send_start(void);
void send_byte(char);
void send_preamble(void);
void send_stop(void);

#endif
