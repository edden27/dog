#ifndef cwcwidth_h
#define cwcwidth_h

#include <wchar.h>

/// Locale-aware wcwidth for Swift on both platforms: measures against a
/// UTF-8 locale so combining marks report 0 and CJK reports 2 (the default
/// C locale reports -1 for all non-ASCII).
int dog_wcwidth(wchar_t wc);

#endif
