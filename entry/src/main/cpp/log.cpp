#include "log.h"
#include <cstdarg>
#include <cstdio>

#ifdef STANDALONE
#else
void hiprintf(int level, const char * fmt, ...) {
    va_list args;
    va_start(args, fmt);
    constexpr int bufsz = 8192;
    char buf[bufsz];
    if (vsnprintf(buf, bufsz, fmt, args) > 0) {
        OH_LOG_Print(LOG_APP, (LogLevel)level, 0, "testTag", "%{public}s", buf);
    }
    va_end(args);
}
#endif