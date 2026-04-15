#ifndef cwcwidth_h
#define cwcwidth_h

#include <wchar.h>

/// Expose wcwidth to Swift on Linux where Glibc doesn't export it.
int dog_wcwidth(wchar_t wc);

#endif
