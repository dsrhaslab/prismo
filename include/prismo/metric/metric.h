#ifndef PRISMO_METRIC_METRIC_H
#define PRISMO_METRIC_METRIC_H

#include <cstdint>
#include <chrono>
#include <thread>
#include <variant>
#include <common/operation.h>

namespace Metric {

    struct NoneMetric {
        ~NoneMetric() {
            std::cout << "~Destroying NoneMetric" << std::endl;
        }
    };

    struct BaseMetric {
        uint64_t block_id = 0;
        uint32_t compression = 0;
        uint64_t start_ns = 0;
        uint64_t end_ns = 0;
        size_t processed_bytes = 0;
        Operation::OperationType operation_type = Operation::OperationType::NOP;

        ~BaseMetric() {
            std::cout << "~Destroying BaseMetric" << std::endl;
        }
    };

    struct StandardMetric : BaseMetric {
        pid_t pid = 0;
        uint64_t tid = 0;

        ~StandardMetric() {
            std::cout << "~Destroying StandardMetric" << std::endl;
        }
    };

    struct FullMetric : StandardMetric {
        size_t requested_bytes = 0;
        uint64_t offset = 0;
        int32_t return_code = 0;
        int32_t error_no = 0;

        ~FullMetric() {
            std::cout << "~Destroying FullMetric" << std::endl;
        }
    };


    using MetricVariant = std::variant<
        NoneMetric,
        BaseMetric,
        StandardMetric,
        FullMetric
    >;

    inline uint64_t get_current_timestamp() noexcept {
        return static_cast<uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now().time_since_epoch()
            ).count()
        );
    }

    inline void fill_metric(
        MetricVariant& metric,
        Operation::OperationType op,
        uint64_t block_id,
        uint32_t compression,
        uint64_t start_ts,
        ssize_t result,
        size_t size,
        uint64_t offset
    ) {
        std::visit([&](auto& m) {
            using T = std::decay_t<decltype(m)>;

            if constexpr (std::is_base_of_v<BaseMetric, T>) {
                m.operation_type = op;
                m.block_id = block_id;
                m.compression = compression;
                m.start_ns = start_ts;
                m.end_ns = get_current_timestamp();
                m.processed_bytes = (result > 0) ? static_cast<size_t>(result) : 0;
            }

            if constexpr (std::is_base_of_v<StandardMetric, T>) {
                m.pid = ::getpid();
                m.tid = std::hash<std::thread::id>{}(std::this_thread::get_id());
            }

            if constexpr (std::is_base_of_v<FullMetric, T>) {
                m.requested_bytes = size;
                m.offset = offset;
                m.return_code = static_cast<int32_t>(result);
                m.error_no = (result < 0) ? errno : 0;
            }
        }, metric);
    }
}

#endif
