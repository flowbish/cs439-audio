#include "kinetis.h"
#include "frame.h"
#include "transmit.h"
#include "common.h"

void frame_init() {
    // pass for now
}

void frame_send(int8_t *packet) {
    // start sound
    send_start();

    // send preamble
    send_preamble();

    // start sending bits, disable interrupts
    __disable_irq();

    for (int i = 0; i < PACKET_LEN; i++) {
        send_byte(packet[i]);
    }

    // calculate and send crc8
    char crc = crc8(packet, PACKET_LEN);
    send_byte(crc);

    // start sending bits, disable interrupts
    __enable_irq();

    // disable sound
    // clear any buffers
    send_stop();

}

void frame_end() {
    // pass for now
}
