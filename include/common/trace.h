#ifndef TRACE_H
#define TRACE_H

#include <cstdint>

struct TraceRecord {
    uint64_t timestamp;
    uint32_t pid;
    char     process[64];
    uint64_t offset;
    uint32_t size;
    char     rw;
    uint32_t major;
    uint32_t minor;
    uint8_t  hash[64];
};

#endif