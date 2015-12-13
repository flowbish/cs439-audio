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


    // control whether we wait for ACK or not
    int ackWaiting = 0;
    String lastTransmitted = "";
    String sending = "";

    while (1) {
        // check for input from USB serial
        if (Serial1.available() > 0) {
            String input = Serial.readStringUntil('\n');
        }

        // check for input from RS232
        if (Serial.available() > 0) {
            String input = Serial.readStringUntil('\n');
            if (input != "" && input != " ") {
                if (input.indexOf("ACK") == 0) {
                    // ACK response
                    Serial.printf("{\"message\": \"ACK received\"}\r\n");
                }
                else if (input.indexOf("NACK") == 0) {
                    // NACK response
                    Serial.printf("{\"message\": \"NACK received\"}\r\n");
                }
                else if (input.indexOf("FREQS") == 0) {
                    // set frequencies used
                    int end = 0;
                    if (input[input.length()-1] == '\n')
                        end = 1;
                    String freqs_str = input.substring(5, input.length()-end);
                    // parse the frequencies out of this
                    //int freqs[128] = {0};
                    //int num_freqs = 0;
                }
                else if (input.indexOf("SWEEP") == 0) {
                    send_sweep();
                    Serial.printf("{\"message\": \"Sweeping possible frequencies\"}\r\n");
                }
                else if (input.indexOf("DURATION") == 0) {
                    // set duration
                    int end = 0;
                    if (input[input.length()-1] == '\n')
                        end = 1;
                    String duration_str = input.substring(8, input.length()-end);
                    int duration = duration_str.toInt();
                    set_duration(duration);
                    Serial.printf("{\"message\": \"Setting duration to %d\"}\r\n", duration);
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
                    Serial.printf("{\"message\": \"Setting MTU to %d\"}\r\n", mtu);
                }
                else {
                    // unknown input
                    //Serial.printf("Unknown input received: \"%s\"", input.c_str());

                    // TODO: move back to other area
                    sending += input;

                    // don't send packet if input is blank
                    while (sending != "" && sending != "\n") {
                        // allocate packet buffer and set the bytes within
                        char packet[get_mtu()];
                        memset(packet, 0, sizeof(packet));
                        strncpy(packet, sending.c_str(), get_mtu());

                        if (sending.length() > get_mtu()) {
                            sending = sending.substring(get_mtu(), sending.length());
                        }
                        else {
                            sending = "";
                        }

                        send_packet_serial(packet);

                        ackWaiting = 1;
                        ackWaiting++;

                        // wait extra time between each packet to let the receiver
                        //  settle
                        delay(3*get_duration());
                    }
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
    char packet_str[get_mtu()*10+40], hex[8];
    memset(packet_str, 0, sizeof(packet_str));

    // begin the json string
    strcat(packet_str, "{\"data\": [");

    size_t i;
    for (i = 0; i < get_mtu(); i++) {
        if (i != 0) {
            strcat(packet_str, ", ");
        }
        snprintf(hex, 7, "\"0x%02x\"", packet[i]);
        strcat(packet_str, hex);
    }

    strcat(packet_str, "], \"crc\":");
    sprintf(hex, "\"0x%02x\"", crc);
    strcat(packet_str, hex);

    // finish the json
    strcat(packet_str, "}\r\n");

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
