#ifndef ND_TEXT_RASTER_H
#define ND_TEXT_RASTER_H

#define ND_TEXT_RASTER_FAILED (-1)
#define ND_TEXT_RASTER_BAD_TEXT (-2)

int nd_text_raster(const char *utf8, int utf8_len, const char *family_utf8, int cell_px,
                   unsigned char *out_bgra, int max_glyphs, float *out_width,
                   int *out_byte_start, int *out_byte_len);

#endif
