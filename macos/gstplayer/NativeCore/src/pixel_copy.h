#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

/* Shared bounds-checked BGRA copy for live frames and thumbnail samples. */
static inline bool gstp_copy_bgra_rows(uint8_t *dst, size_t dst_len,
    const uint8_t *src, size_t src_len, int32_t width, int32_t height,
    int32_t src_stride) {
  if (!dst || !src || width <= 0 || height <= 0 || src_stride <= 0) return false;
  const size_t row = (size_t)width * 4;
  if (row > UINT32_MAX || (size_t)height > UINT32_MAX / row ||
      row * (size_t)height > dst_len || (size_t)src_stride < row ||
      (size_t)(height - 1) > (SIZE_MAX - row) / (size_t)src_stride ||
      (size_t)(height - 1) * (size_t)src_stride + row > src_len) return false;
  for (int32_t y = 0; y < height; y++) {
    memcpy(dst + (size_t)y * row, src + (size_t)y * (size_t)src_stride, row);
  }
  return true;
}

/* Both Flutter desktop pixel-buffer backends use tight RGBA output. */
static inline void gstp_bgra_to_rgba(const uint8_t *src, int32_t width,
    int32_t height, int32_t stride, uint8_t *dst) {
  for (int32_t y = 0; y < height; y++) {
    const uint8_t *in = src + (size_t)y * (size_t)stride;
    uint8_t *out = dst + (size_t)y * (size_t)width * 4;
    for (int32_t x = 0; x < width; x++) {
      out[x * 4] = in[x * 4 + 2];
      out[x * 4 + 1] = in[x * 4 + 1];
      out[x * 4 + 2] = in[x * 4];
      out[x * 4 + 3] = in[x * 4 + 3];
    }
  }
}
