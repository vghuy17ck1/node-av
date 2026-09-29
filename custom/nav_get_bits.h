// Minimal stand-in for FFmpeg's internal get_bits.h, for builds against shared FFmpeg
#pragma once
#include <stdint.h>

typedef struct GetBitContext {
  const uint8_t* buffer;
  int size_in_bits;
  int index;
} GetBitContext;

static inline int init_get_bits8(GetBitContext* s, const uint8_t* buffer, int byte_size) {
  if (byte_size < 0 || !buffer) return -1;
  s->buffer = buffer;
  s->size_in_bits = byte_size * 8;
  s->index = 0;
  return 0;
}

static inline unsigned int get_bits1(GetBitContext* s) {
  if (s->index >= s->size_in_bits) return 0;
  unsigned int bit = (s->buffer[s->index >> 3] >> (7 - (s->index & 7))) & 1;
  s->index++;
  return bit;
}

static inline unsigned int get_bits(GetBitContext* s, int n) {
  unsigned int value = 0;
  for (int i = 0; i < n; i++) value = (value << 1) | get_bits1(s);
  return value;
}
