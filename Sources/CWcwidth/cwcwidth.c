#define _XOPEN_SOURCE 700
#include <wchar.h>

int dog_wcwidth(wchar_t wc) {
  return wcwidth(wc);
}
