#ifdef STANDALONE
#define LOG_INFO(fmt, ...) fprintf(stderr, fmt "\n", __VA_ARGS__)
#define LOG_WARN(fmt, ...) fprintf(stderr, fmt "\n", __VA_ARGS__)
#define LOG_ERROR(fmt, ...) fprintf(stderr, fmt "\n", __VA_ARGS__)
#else
#include "hilog/log.h"
#undef LOG_DEBUG
#undef LOG_INFO
#undef LOG_WARN
#undef LOG_ERROR
#undef LOG_FATAL
extern void hiprintf(int level, const char * fmt, ...);
// supress logs
//#define hiprintf(...)
#define LOG_DEBUG(...) hiprintf(3, __VA_ARGS__)
#define LOG_INFO(...) hiprintf(4, __VA_ARGS__)
#define LOG_WARN(...) hiprintf(5, __VA_ARGS__)
#define LOG_ERROR(...) hiprintf(6, __VA_ARGS__)
#define LOG_FATAL(...) hiprintf(7, __VA_ARGS__)
#endif