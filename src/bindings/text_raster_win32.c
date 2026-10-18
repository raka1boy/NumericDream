#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dwrite.h>
#include <d2d1.h>
#include <wincodec.h>
#include <string.h>
#include <stdlib.h>

#include "text_raster.h"

static const GUID nd_iid_d2d1_factory = { 0x06152247, 0x6f50, 0x465a, { 0x92, 0x45, 0x11, 0x8b, 0xfd, 0x3b, 0x60, 0x07 } };
static const GUID nd_iid_dwrite_factory = { 0xb859ee5a, 0xd838, 0x4b5b, { 0xa2, 0xe8, 0x1a, 0xdc, 0x7d, 0x93, 0xdb, 0x48 } };
static const GUID nd_clsid_wic_factory = { 0xcacaf262, 0x9370, 0x4615, { 0xa1, 0x3b, 0x9f, 0x55, 0x39, 0xda, 0x4c, 0x0a } };
static const GUID nd_iid_wic_factory = { 0xec5ec8a9, 0xc395, 0x4314, { 0x9c, 0x77, 0x54, 0xd7, 0xa9, 0x35, 0xff, 0x70 } };
static const GUID nd_wic_format_pbgra = { 0x6fddc324, 0x4e03, 0x4bfe, { 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x10 } };

#define ND_MAX_CLUSTERS 1024

typedef struct {
    ID2D1Factory *d2d;
    IDWriteFactory *dw;
    IWICImagingFactory *wic;
    IWICBitmap *bitmap;
    ID2D1RenderTarget *rt;
    ID2D1SolidColorBrush *brush;
    IDWriteTextFormat *format;
    int com_owned;
} NdRaster;

static void nd_release(NdRaster *r) {
    if (r->format) IDWriteTextFormat_Release(r->format);
    if (r->brush) ID2D1SolidColorBrush_Release(r->brush);
    if (r->rt) ID2D1RenderTarget_Release(r->rt);
    if (r->bitmap) IWICBitmap_Release(r->bitmap);
    if (r->wic) IWICImagingFactory_Release(r->wic);
    if (r->dw) IDWriteFactory_Release(r->dw);
    if (r->d2d) ID2D1Factory_Release(r->d2d);
    if (r->com_owned) CoUninitialize();
}

static WCHAR *nd_widen(const char *utf8, int len, int *out_len) {
    int n = MultiByteToWideChar(CP_UTF8, 0, utf8, len, NULL, 0);
    if (n <= 0) return NULL;
    WCHAR *w = (WCHAR *)malloc(sizeof(WCHAR) * (size_t)(n + 1));
    if (!w) return NULL;
    MultiByteToWideChar(CP_UTF8, 0, utf8, len, w, n);
    w[n] = 0;
    *out_len = n;
    return w;
}

static int nd_utf8_len_of_unit(const WCHAR *w, int i, int n, int *units) {
    unsigned c = w[i];
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < n) {
        *units = 2;
        return 4;
    }
    *units = 1;
    if (c < 0x80) return 1;
    if (c < 0x800) return 2;
    return 3;
}

static int nd_is_regional_indicator(const WCHAR *w) {
    return w[0] == 0xD83C && w[1] >= 0xDDE6 && w[1] <= 0xDDFF;
}

int nd_text_raster(const char *utf8, int utf8_len, const char *family_utf8, int cell_px,
                   unsigned char *out_bgra, int max_glyphs, float *out_width,
                   int *out_byte_start, int *out_byte_len) {
    if (utf8_len <= 0 || max_glyphs <= 0 || cell_px <= 0) return 0;

    NdRaster r;
    memset(&r, 0, sizeof(r));
    HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    if (hr == S_OK || hr == S_FALSE) r.com_owned = 1;

    int wlen = 0;
    WCHAR *wtext = nd_widen(utf8, utf8_len, &wlen);
    if (!wtext) {
        nd_release(&r);
        return ND_TEXT_RASTER_BAD_TEXT;
    }

    int *byte_at = (int *)malloc(sizeof(int) * (size_t)(wlen + 1));
    if (!byte_at) {
        free(wtext);
        nd_release(&r);
        return ND_TEXT_RASTER_FAILED;
    }
    {
        int b = 0;
        int i = 0;
        while (i < wlen) {
            int units = 1;
            int bytes = nd_utf8_len_of_unit(wtext, i, wlen, &units);
            byte_at[i] = b;
            if (units == 2) byte_at[i + 1] = b;
            b += bytes;
            i += units;
        }
        byte_at[wlen] = b;
    }

    int result = ND_TEXT_RASTER_FAILED;
    const float em = (float)cell_px * 0.75f;
    const float baseline_target = (float)cell_px * 0.74f;

    WCHAR family[128] = L"Consolas";
    if (family_utf8 && family_utf8[0]) {
        int fl = MultiByteToWideChar(CP_UTF8, 0, family_utf8, -1, family, 127);
        if (fl <= 1) wcscpy(family, L"Consolas");
        family[127] = 0;
    }

    if (FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &nd_iid_d2d1_factory, NULL, (void **)&r.d2d))) goto done;
    if (FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, &nd_iid_dwrite_factory, (IUnknown **)&r.dw))) goto done;
    if (FAILED(CoCreateInstance(&nd_clsid_wic_factory, NULL, CLSCTX_INPROC_SERVER, &nd_iid_wic_factory, (void **)&r.wic))) goto done;
    if (FAILED(IWICImagingFactory_CreateBitmap(r.wic, (UINT)cell_px, (UINT)cell_px, &nd_wic_format_pbgra, WICBitmapCacheOnLoad, &r.bitmap))) goto done;

    D2D1_RENDER_TARGET_PROPERTIES props;
    memset(&props, 0, sizeof(props));
    props.type = D2D1_RENDER_TARGET_TYPE_DEFAULT;
    props.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    props.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    props.dpiX = 96.0f;
    props.dpiY = 96.0f;
    props.usage = D2D1_RENDER_TARGET_USAGE_NONE;
    props.minLevel = D2D1_FEATURE_LEVEL_DEFAULT;
    if (FAILED(ID2D1Factory_CreateWicBitmapRenderTarget(r.d2d, r.bitmap, &props, &r.rt))) goto done;
    ID2D1RenderTarget_SetTextAntialiasMode(r.rt, D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);

    D2D1_COLOR_F white = { 1.0f, 1.0f, 1.0f, 1.0f };
    if (FAILED(ID2D1RenderTarget_CreateSolidColorBrush(r.rt, &white, NULL, &r.brush))) goto done;

    hr = IDWriteFactory_CreateTextFormat(r.dw, family, NULL, DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL,
                                         DWRITE_FONT_STRETCH_NORMAL, em, L"en-us", &r.format);
    if (FAILED(hr)) {
        hr = IDWriteFactory_CreateTextFormat(r.dw, L"Consolas", NULL, DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL,
                                             DWRITE_FONT_STRETCH_NORMAL, em, L"en-us", &r.format);
        if (FAILED(hr)) goto done;
    }
    IDWriteTextFormat_SetWordWrapping(r.format, DWRITE_WORD_WRAPPING_NO_WRAP);

    IDWriteTextLayout *whole = NULL;
    if (FAILED(IDWriteFactory_CreateTextLayout(r.dw, wtext, (UINT32)wlen, r.format, 1.0e6f, 1.0e6f, &whole))) goto done;
    static DWRITE_CLUSTER_METRICS clusters[ND_MAX_CLUSTERS];
    UINT32 cluster_count = 0;
    hr = IDWriteTextLayout_GetClusterMetrics(whole, clusters, ND_MAX_CLUSTERS, &cluster_count);
    IDWriteTextLayout_Release(whole);
    if (FAILED(hr)) goto done;

    int glyphs = 0;
    int unit = 0;
    const size_t cell_bytes = (size_t)cell_px * (size_t)cell_px * 4;
    for (UINT32 c = 0; c < cluster_count && glyphs < max_glyphs; c++) {
        const int start = unit;
        int count = (int)clusters[c].length;
        if (count == 2 && c + 1 < cluster_count && clusters[c + 1].length == 2 &&
            nd_is_regional_indicator(wtext + start) && nd_is_regional_indicator(wtext + start + 2)) {
            count += 2;
            c++;
        }
        unit += count;
        if (count <= 0) continue;

        IDWriteTextLayout *layout = NULL;
        if (FAILED(IDWriteFactory_CreateTextLayout(r.dw, wtext + start, (UINT32)count, r.format, 1.0e6f, 1.0e6f, &layout))) continue;

        DWRITE_TEXT_METRICS tm;
        DWRITE_LINE_METRICS lm[4];
        UINT32 lines = 0;
        float width = 0.0f;
        float baseline = em * 0.8f;
        if (SUCCEEDED(IDWriteTextLayout_GetMetrics(layout, &tm))) width = tm.widthIncludingTrailingWhitespace;
        if (SUCCEEDED(IDWriteTextLayout_GetLineMetrics(layout, lm, 4, &lines)) && lines > 0) baseline = lm[0].baseline;

        const float cell = (float)cell_px;
        const float s = width > cell * 0.98f ? cell * 0.98f / width : 1.0f;
        const float ox = (cell - width) * 0.5f;
        const float oy = baseline_target - baseline;
        D2D1_MATRIX_3X2_F m = { s, 0.0f, 0.0f, s, cell * 0.5f * (1.0f - s) + s * ox, cell * 0.5f * (1.0f - s) + s * oy };

        D2D1_COLOR_F clear = { 0.0f, 0.0f, 0.0f, 0.0f };
        D2D1_POINT_2F origin = { 0.0f, 0.0f };
        ID2D1RenderTarget_BeginDraw(r.rt);
        ID2D1RenderTarget_Clear(r.rt, &clear);
        ID2D1RenderTarget_SetTransform(r.rt, &m);
        ID2D1RenderTarget_DrawTextLayout(r.rt, origin, layout, (ID2D1Brush *)r.brush,
                                         D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT | D2D1_DRAW_TEXT_OPTIONS_NO_SNAP);
        hr = ID2D1RenderTarget_EndDraw(r.rt, NULL, NULL);
        IDWriteTextLayout_Release(layout);
        if (FAILED(hr)) continue;

        unsigned char *dst = out_bgra + cell_bytes * (size_t)glyphs;
        memset(dst, 0, cell_bytes);
        WICRect rect = { 0, 0, cell_px, cell_px };
        IWICBitmapLock *lock = NULL;
        if (SUCCEEDED(IWICBitmap_Lock(r.bitmap, &rect, WICBitmapLockRead, &lock))) {
            UINT stride = 0;
            UINT size = 0;
            BYTE *data = NULL;
            IWICBitmapLock_GetStride(lock, &stride);
            IWICBitmapLock_GetDataPointer(lock, &size, &data);
            if (data) {
                for (int y = 0; y < cell_px; y++) {
                    memcpy(dst + (size_t)y * (size_t)cell_px * 4, data + (size_t)y * stride, (size_t)cell_px * 4);
                }
            }
            IWICBitmapLock_Release(lock);
        }

        out_width[glyphs] = width * s / cell;
        out_byte_start[glyphs] = byte_at[start];
        out_byte_len[glyphs] = byte_at[start + count] - byte_at[start];
        glyphs++;
    }
    result = glyphs;

done:
    free(byte_at);
    free(wtext);
    nd_release(&r);
    return result;
}
