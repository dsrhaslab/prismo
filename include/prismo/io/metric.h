#ifndef IO_METRIC_H
#define IO_METRIC_H

#include <cstdint>
#include <chrono>
#include <thread>
#include <common/operation.h>

namespace Metric {

    enum class MetricType {
        None = 0,
        Base = 1,
        Standard = 2,
        Full = 3,
    };

    struct Metric {
        MetricType type;

        explicit Metric(MetricType t) : type(t) {}
        virtual ~Metric() = default;

        Metric(const Metric&) = default;
        Metric& operator=(const Metric&) = default;

        Metric(Metric&&) = default;
        Metric& operator=(Metric&&) = default;

        virtual Metric* clone() const = 0;
    };

    struct NoneMetric : Metric {
        NoneMetric() : Metric(MetricType::None) {}

        NoneMetric* clone() const override {
            return new NoneMetric(*this);
        }
    };

    struct BaseMetric : Metric {
        uint64_t block_id;
        uint32_t compression;
        uint64_t start_timestamp;
        uint64_t end_timestamp;
        Operation::OperationType operation_type{};

        BaseMetric() : Metric(MetricType::Base) {}

        BaseMetric* clone() const override {
            return new BaseMetric(*this);
        }
    };

    struct StandardMetric : BaseMetric {
        pid_t pid;
        uint64_t tid;

        StandardMetric() : BaseMetric() {
            this->type = MetricType::Standard;
        }

        StandardMetric* clone() const override {
            return new StandardMetric(*this);
        }
    };

    struct FullMetric : StandardMetric {
        size_t requested_bytes;
        size_t processed_bytes;
        uint64_t offset;
        int32_t return_code;
        int32_t error_no;

        FullMetric() : StandardMetric() {
            this->type = MetricType::Full;
        }

        FullMetric* clone() const override {
            return new FullMetric(*this);
        }
    };

    inline uint64_t get_current_timestamp() noexcept {
        return std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count();
    }

    inline void fill_metric(
        Metric& metric,
        Operation::OperationType op,
        uint64_t block_id,
        uint32_t compression,
        uint64_t start_ts,
        uint64_t end_ts,
        ssize_t result,
        size_t size,
        uint64_t offset
    ) {
        if (metric.type < MetricType::Base) {
            return;
        }

        auto& base = static_cast<BaseMetric&>(metric);
        base.operation_type  = op;
        base.block_id = block_id;
        base.compression = compression;
        base.start_timestamp = start_ts;
        base.end_timestamp   = end_ts;

        if (metric.type < MetricType::Standard) {
            return;
        }

        auto& standard = static_cast<StandardMetric&>(metric);
        standard.pid = ::getpid();
        standard.tid = std::hash<std::thread::id>{}(std::this_thread::get_id());

        if (metric.type < MetricType::Full) {
            return;
        }

        auto& full = static_cast<FullMetric&>(metric);
        full.requested_bytes = size;
        full.offset          = offset;
        full.processed_bytes = (result > 0) ? static_cast<size_t>(result) : 0;
        full.return_code     = static_cast<int32_t>(result);
        full.error_no        = (result < 0) ? errno : 0;
    }
}

#endif