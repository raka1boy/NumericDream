/*
  NumericDream's trimmed SDL3 build configuration.

  Based on SDL's own non-CMake Windows config
  (include/build_config/SDL_build_config_windows.h), reduced to only the
  subsystems this app needs: video + events + input plumbing for a window
  that WebGPU (via wgpu-native) renders into directly. SDL owns no graphics
  API of its own here -- no SDL_GPU, no SDL_Renderer, no OpenGL/Vulkan/D3D --
  we only use SDL for window creation, the win32 HWND handle, and the event
  loop. Audio, camera, joystick, haptic, sensor, hidapi, dialog, process,
  tray, storage, and every graphics backend are compiled out entirely so we
  don't need MSVC/Windows-SDK-only headers that zig's bundled mingw-w64
  headers may not carry.
*/

#ifndef SDL_build_config_h_
#define SDL_build_config_h_

#include <SDL3/SDL_platform_defines.h>

#if !defined(HAVE_STDINT_H) && !defined(_STDINT_H_)
#define HAVE_STDINT_H 1
#endif

#ifdef __clang__
#define HAVE_GCC_ATOMICS 1
#endif

#define HAVE_STDARG_H 1
#define HAVE_STDDEF_H 1

/* Real DirectInput/XInput headers, needed by the joystick backends below --
   without these, SDL_directx.h falls back to stub typedefs and every
   DirectInput type/constant goes missing. */
#define HAVE_DINPUT_H 1
#define HAVE_XINPUT_H 1

#ifndef HAVE_LIBC
#define HAVE_LIBC 1
#endif

#if HAVE_LIBC
#define HAVE_FLOAT_H 1
#define HAVE_LIMITS_H 1
#define HAVE_MATH_H 1
#define HAVE_SIGNAL_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_WCHAR_H 1

#define HAVE_MALLOC 1
#define HAVE_ABS 1
#define HAVE_MEMSET 1
#define HAVE_MEMCPY 1
#define HAVE_MEMMOVE 1
#define HAVE_MEMCMP 1
#define HAVE_STRLEN 1
#define HAVE__STRREV 1
#define HAVE_STRCHR 1
#define HAVE_STRRCHR 1
#define HAVE_STRSTR 1
#define HAVE_STRTOL 1
#define HAVE_STRTOUL 1
#define HAVE_STRTOD 1
#define HAVE_ATOI 1
#define HAVE_ATOF 1
#define HAVE_STRCMP 1
#define HAVE_STRNCMP 1
#define HAVE_STRPBRK 1
#define HAVE_VSNPRINTF 1
#define HAVE_ACOS 1
#define HAVE_ASIN 1
#define HAVE_ATAN 1
#define HAVE_ATAN2 1
#define HAVE_CEIL 1
#define HAVE_COS 1
#define HAVE_EXP 1
#define HAVE_FABS 1
#define HAVE_FLOOR 1
#define HAVE_FMOD 1
#define HAVE_ISINF 1
#define HAVE_ISINF_FLOAT_MACRO 1
#define HAVE_ISNAN 1
#define HAVE_ISNAN_FLOAT_MACRO 1
#define HAVE_LOG 1
#define HAVE_LOG10 1
#define HAVE_POW 1
#define HAVE_SIN 1
#define HAVE_SQRT 1
#define HAVE_TAN 1
#define HAVE_ACOSF 1
#define HAVE_ASINF 1
#define HAVE_ATANF 1
#define HAVE_ATAN2F 1
#define HAVE_CEILF 1
#define HAVE__COPYSIGN 1
#define HAVE_COSF 1
#define HAVE_EXPF 1
#define HAVE_FABSF 1
#define HAVE_FLOORF 1
#define HAVE_FMODF 1
#define HAVE_LOGF 1
#define HAVE_LOG10F 1
#define HAVE_POWF 1
#define HAVE_SINF 1
#define HAVE_SQRTF 1
#define HAVE_TANF 1
#define HAVE_STRTOLL 1
#define HAVE_STRTOULL 1
#define HAVE_VSSCANF 1
#define HAVE_LROUND 1
#define HAVE_LROUNDF 1
#define HAVE_ROUND 1
#define HAVE_ROUNDF 1
#define HAVE_SCALBN 1
#define HAVE_SCALBNF 1
#define HAVE_TRUNC 1
#define HAVE_TRUNCF 1
#endif /* HAVE_LIBC */

/* --- Subsystems this baseline does NOT need: compiled out entirely --- */
#define SDL_AUDIO_DISABLED 1
#define SDL_CAMERA_DISABLED 1
#define SDL_HAPTIC_DISABLED 1
#define SDL_HIDAPI_DISABLED 1
#define SDL_SENSOR_DISABLED 1
#define SDL_DIALOG_DISABLED 1
#define SDL_POWER_DISABLED 1

/* --- Subsystems this baseline needs --- */
/* Joystick/gamepad: handy for flying through 3D fractals with a
   controller. DirectInput + XInput + the virtual-joystick backend only --
   HIDAPI and the newer WGI/GameInput APIs are left off (see
   SDL_windows_gaming_input.c / SDL_windowsgameinput.cpp / SDL_gameinput.cpp,
   which all no-op cleanly when their HAVE_*_H macro isn't defined). */
#define SDL_JOYSTICK_DINPUT 1
#define SDL_JOYSTICK_XINPUT 1
#define SDL_JOYSTICK_VIRTUAL 1

/* Same story for the system tray: SDL_events.c/SDL_tray_utils.c call these
   unconditionally regardless of whether the app ever creates a tray icon. */
#define SDL_TRAY_DUMMY 1

/* SDL_video.c's window-texture convenience path depends on the Renderer
   subsystem always being compiled in; keep it software-only. */
#define SDL_THREAD_GENERIC_COND_SUFFIX 1
#define SDL_THREAD_GENERIC_RWLOCK_SUFFIX 1
#define SDL_THREAD_WINDOWS 1

#define SDL_TIME_WINDOWS 1
#define SDL_TIMER_WINDOWS 1

#define SDL_VIDEO_DRIVER_WINDOWS 1

/* No SDL graphics backend at all: WebGPU (wgpu-native) owns rendering,
   driven straight off the win32 HWND we pull from SDL's window properties. */
#define SDL_GPU_DISABLED 1

#define SDL_LOADSO_WINDOWS 1
#define SDL_FILESYSTEM_WINDOWS 1
#define SDL_FSOPS_WINDOWS 1
#define SDL_PROCESS_DUMMY 1

#endif /* SDL_build_config_h_ */
