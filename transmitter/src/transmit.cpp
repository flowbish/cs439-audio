#include <transmit.h>

unsigned int duration = 0;
unsigned int mtu = 10;

void set_mtu(unsigned int m) {
    mtu = m;
}

unsigned int get_mtu() {
    return mtu;
}

void set_duration(unsigned int m) {
    duration = m;
}

unsigned int get_duration() {
    return duration;
}
