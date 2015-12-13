#include <string.h>
#include <stdint.h>
#include <WProgram.h>
#include <Wire.h>
#include <Audio.h>
#include <SPI.h>
#include "transmit.h"
#include "frame.h"
#include "common.h"

void send_demo();
void send_packet_serial(char *);
void send_packet(char *);
void send_preamble(void);

int main(void) {

    // initialize USB serial connection
    Serial.begin(115200);

    // initialize UART serial connection
    // RX1 - pin 0
    // TX1 - pin 1
    Serial1.begin(9600);

    // allocate audio memory
    AudioMemory(18);

    // pin 2 is connected to a button to ground, for a simple demo
    pinMode(2, INPUT_PULLUP);

    while (1) {
        // check for input from USB serial
        if (Serial1.available() > 0) {
            String input = Serial.readStringUntil('\n');

            // don't send packet if input is blank
            while (input != "" && input != "\n") {
                // allocate packet buffer and set the bytes within
                char packet[get_mtu()];
                memset(packet, 0, sizeof(packet));
                strncpy(packet, input.c_str(), get_mtu());

                if (input.length() > get_mtu()) {
                    input = input.substring(get_mtu(), input.length());
                }
                else {
                    input = "";
                }

                send_packet_serial(packet);

                // wait extra time between each packet to let the receiver
                //  settle
                delay(3*get_duration());
            }
        }

        // check for input from RS232
        if (Serial.available() > 0) {
            String input = Serial.readStringUntil('\n');
            if (input != "" && input != " ") {
                if (input.indexOf("ACK") == 0) {
                    // ACK response
                }
                else if (input.indexOf("NACK") == 0) {
                    // NACK response
                }
                else if (input.indexOf("FREQS") == 0) {
                    // set frequencies used
                }
                else if (input.indexOf("MTU") == 0) {
                    // set MTU
                    // formatted "MTU<number>\n"
                    int end = 0;
                    if (input[input.length()-1] == '\n')
                        end = 1;
                    String mtu_str = input.substring(3, input.length()-end);
                    int mtu = mtu_str.toInt();
                    set_mtu(mtu);
                    Serial.printf("Setting MTU to %d\r\n", mtu);
                }
                else {
                    // unknown input
                    //Serial.printf("Unknown input received: \"%s\"", input.c_str());
                }
            }
        }

        // check for button press on pin 2
        if (!digitalRead(2)) {
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
    char packet[get_mtu()];
    memset(packet, 0, sizeof(packet));
    strncpy(packet, "Hi Robin!!", get_mtu());

    send_packet(packet);
}

/**
 * Send out a packet and also send back a confirmation over serial of the byte
 *  sequence sent.
 */
void send_packet_serial(char *packet) {
    // calculate CRC8
    char crc = crc8(packet, get_mtu());

    // generate a string representing the bytes of the packet being sent
    char packet_str[500], hex[8];
    size_t i;
    memset(packet_str, 0, sizeof(packet_str));
    for (i = 0; i < get_mtu(); i++) {
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
    // packet must be at least get_mtu() bytes (or must it?)
  frame_init();
  frame_send((int8_t*)packet);
  frame_end();
}
