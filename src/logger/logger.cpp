#include <prismo/logger/logger.hpp>

namespace Logger {

    Base::Base(uint64_t _avg_interval_ms)
        : avg_interval_ms(_avg_interval_ms),
          last_avg_time(std::chrono::steady_clock::now()) {}

    Base::~Base() {
        std::cout << "~Destroying Logger" << std::endl;
    }

    Metric::Metric Base::merge(const std::vector<Metric::Metric>& metrics) const {
        Metric::Metric merged{};
        size_t n = metrics.size();
        merged.start_ns = UINT64_MAX;

        for (const auto& m : metrics) {
            merged.start_ns = std::min(merged.start_ns, m.start_ns);
            merged.end_ns = std::max(merged.end_ns, m.end_ns);
            merged.processed_bytes += m.processed_bytes;
            merged.requested_bytes += m.requested_bytes;
        }

        merged.operation_type = metrics.front().operation_type;
        merged.pid = metrics.front().pid;
        merged.tid = metrics.front().tid;
        merged.processed_bytes /= n;
        merged.requested_bytes /= n;

        merged.block_id = 0;
        merged.compression = 0;
        merged.offset = 0;
        merged.return_code = 0;
        merged.error_no = 0;

        return merged;
    }

    void Base::info(const Metric::Metric& metric) {
        metrics_by_op[metric.operation_type].push_back(metric);

        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - last_avg_time
        ).count();

        if (static_cast<uint64_t>(elapsed) >= avg_interval_ms) {
            for (auto& [op_type, op_metrics] : metrics_by_op) {
                if (!op_metrics.empty()) {
                    Metric::Metric merged_metric = merge(op_metrics);
                    write(merged_metric);
                    op_metrics.clear();
                }
            }
            last_avg_time = now;
        }
    }
};
