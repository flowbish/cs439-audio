#include "WProgram.h"
#include "Wire.h"
#include "Audio.h"
#include <string.h>
#include <assert.h>
#include "SPI.h"
#include "transmit.h"

void send_demo();
void send_packet_serial(char *);
void send_packet(char *);
void send_preamble(void);

uint8_t crc8(const void *vptr, int len) {
	const uint8_t *data = (const uint8_t*)vptr;
	uint16_t crc = 0;
	int i, j;
	for (j = len; j; j--, data++) {
		crc ^= (*data << 8);
		for(i = 8; i; i--) {
			if (crc & 0x8000)
				crc ^= (0x1D50 << 3);
			crc <<= 1;
		}
	}
	return (uint8_t)(crc >> 8);
} 

extern "C" int main(void) {

    // initialize serial connection
    Serial.begin(115200);

    // allocate audio memory
    AudioMemory(18);

    // pin 2 is connected to a button to ground, for a simple demo
    pinMode(2, INPUT_PULLUP);

	while (1) {
        if (Serial.available() > 0) {
            String input = Serial.readStringUntil('\n');

            // don't send packet if input is blank
            if (input != "" && input != "\n") {
                // allocate packet buffer and set the bytes within
                char packet[PACKET_LEN];
                memset(packet, 0, sizeof(packet));
                strncpy(packet, input.c_str(), PACKET_LEN);

                send_packet_serial(packet);
                
                // wait extra time between each packet to let the receiver
                //  settle
                delay(3*DURATION);
            }
        }
        else if (!digitalRead(2)) {
            // pin 2 connected to ground, send demo packet
            send_demo();
        }
	}
}

/**
 * Send out a single demonstration packet to impress the professor.
 */
void send_demo() {
    // allocate packet buffer and set the bytes within
    char packet[PACKET_LEN];
    memset(packet, 0, sizeof(packet));
    strncpy(packet, "Hi Robin!!", PACKET_LEN);

    send_packet(packet);
}

/**
 * Send out a packet and also send back a confirmation over serial of the byte
 *  sequence sent.
 */
void send_packet_serial(char *packet) {
    // calculate CRC8
    char crc = crc8(packet, PACKET_LEN);

    // generate a string representing the bytes of the packet being sent
    char packet_str[100], hex[8];
    size_t i;
    sprintf(packet_str, "0x55 0x55");
    for (i = 0; i < PACKET_LEN; i++) {
        snprintf(hex, 7, " 0x%02x", packet[i]);
        strcat(packet_str, hex);
    }
    sprintf(hex, "0x%02x\r\n", crc);
    strcat(packet_str, hex);
    Serial.print(packet_str);

    // send the packet!
    send_packet(packet);
}

void send_packet(char *packet) {
    // packet must be at least PACKET_LEN bytes

    // calculate CRC8
    char crc = crc8(packet, PACKET_LEN);

    // start sending bits, disable interrupts
    __disable_irq();

    // send start of packet
    send_preamble();

    // send packet
    int i;
    for (i = 0; i < PACKET_LEN; i++) {
        send_byte(packet[i]);
    }

    // send crc
    send_byte(crc);

    // disable sound
    send_stop();

    // end sending bit, enable interrupts
    __enable_irq();
}
