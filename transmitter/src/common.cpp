#include "common.h"
#include "frame.h"
#include "transmit.h"

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
