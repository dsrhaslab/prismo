#ifndef COMMON_TRACE_H
#define COMMON_TRACE_H

#include <cstdint>
#include <common/operation.hpp>

namespace Trace {
    struct Record {
        uint64_t timestamp;
        uint32_t pid;
        uint64_t process;
        uint64_t offset;
        uint32_t size;
        uint32_t major;
        uint32_t minor;
        uint64_t block_id;
        Operation::OperationType operation;
    };
}

#endif