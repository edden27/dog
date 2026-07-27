#define _XOPEN_SOURCE 700
#include <wchar.h>
#include <locale.h>
#if defined(__APPLE__)
#include <xlocale.h>
#endif

int dog_wcwidth(wchar_t wc) {
  // wcwidth in the default C locale returns -1 for every non-ASCII
  // character, so a UTF-8 locale is required for real width data
  // (0 for combining marks, 2 for CJK). C.UTF-8 is compiled into glibc;
  // macOS ships UTF-8/en_US.UTF-8.
  static locale_t utf8_locale;
  static int initialized;
  if (!initialized) {
    utf8_locale = newlocale(LC_CTYPE_MASK, "C.UTF-8", (locale_t)0);
    if (!utf8_locale) utf8_locale = newlocale(LC_CTYPE_MASK, "UTF-8", (locale_t)0);
    if (!utf8_locale) utf8_locale = newlocale(LC_CTYPE_MASK, "en_US.UTF-8", (locale_t)0);
    initialized = 1;
  }
  if (utf8_locale) return wcwidth_l(wc, utf8_locale);
  return wcwidth(wc);
}
