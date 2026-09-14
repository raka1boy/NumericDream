#ifndef NUMERICDREAM_INTRIN_SHIM_H
#define NUMERICDREAM_INTRIN_SHIM_H

#ifdef __cplusplus
extern "C" {
#endif

extern void __cdecl __debugbreak(void);
unsigned short __cdecl _byteswap_ushort(unsigned short value);
unsigned long __cdecl _byteswap_ulong(unsigned long value);
unsigned long long __cdecl _byteswap_uint64(unsigned long long value);

#ifdef __cplusplus
}
#endif

#endif
