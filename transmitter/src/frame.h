#ifndef _FRAME_H
#define _FRAME_H

/**
 * Setup and begin a frame-level transmission
 */
void frame_init(void);

/**
 * Send a series of bytes as a frame
 */
void frame_send(int8_t *packet);

/**
 * Finish a frame level transmission
 */
void frame_end(void);

#endif
