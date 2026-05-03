#ifndef PRISMO_METRIC_METRIC_H
#define PRISMO_METRIC_METRIC_H

#include <cstdint>
#include <chrono>
#include <iostream>
#include <common/operation.hpp>

namespace Metric {

    struct Metric {
        Operation::OperationType operation_type;
        uint64_t block_id;
        uint32_t compression;

        uint64_t start_ns;
        uint64_t end_ns;

        pid_t pid;
        uint64_t tid;

        size_t requested_bytes;
        size_t processed_bytes;
        uint64_t offset;

        int32_t return_code;
        int32_t error_no;
    };

    inline uint64_t get_current_timestamp() noexcept {
        return static_cast<uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now().time_since_epoch()
            ).count()
        );
    }

    inline Metric create_metric(
        Operation::OperationType op,
        uint64_t block_id,
        uint32_t compression,
        uint64_t start_ns,
        pid_t pid,
        uint64_t tid,
        size_t requested_bytes,
        uint64_t offset,
        ssize_t result
    ) {
        return Metric {
            .operation_type = op,
            .block_id = block_id,
            .compression = compression,
            .start_ns = start_ns,
            .end_ns = get_current_timestamp(),
            .pid = pid,
            .tid = tid,
            .requested_bytes = requested_bytes,
            .processed_bytes = (result > 0) ? static_cast<size_t>(result) : 0,
            .offset = offset,
            .return_code = static_cast<int32_t>(result),
            .error_no = (result < 0) ? errno : 0

        };
    }
}

#endif
