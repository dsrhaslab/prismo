#include <prismo/logger/logger.hpp>

namespace Logger {

    Base::Base(uint64_t _avg_interval_ms)
        : avg_interval_ms(_avg_interval_ms),
          last_avg_time(std::chrono::steady_clock::now()) {}

    Base::~Base() {
        std::cout << "~Destroying Logger" << std::endl;
    }

    Metric::Metric Base::compute_average(const std::vector<Metric::Metric>& metrics) const {
        Metric::Metric avg{};
        if (metrics.empty()) return avg;

        size_t n = metrics.size();

        for (const auto& m : metrics) {
            avg.start_ns += m.start_ns;
            avg.end_ns += m.end_ns;
            avg.processed_bytes += m.processed_bytes;
            avg.compression += m.compression;
            avg.requested_bytes += m.requested_bytes;
            avg.offset += m.offset;
            avg.return_code += m.return_code;
            avg.error_no += m.error_no;
        }

        avg.operation_type = metrics.front().operation_type;
        avg.pid = metrics.front().pid;
        avg.tid = metrics.front().tid;
        avg.start_ns /= n;
        avg.end_ns /= n;
        avg.processed_bytes /= n;
        avg.compression = static_cast<uint32_t>(avg.compression / n);
        avg.requested_bytes /= n;
        avg.offset /= n;
        avg.return_code = static_cast<int32_t>(avg.return_code / static_cast<int32_t>(n));
        avg.error_no = static_cast<int32_t>(avg.error_no / static_cast<int32_t>(n));

        return avg;
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
                    Metric::Metric avg_metric = compute_average(op_metrics);
                    write(avg_metric);
                    op_metrics.clear();
                }
            }
            last_avg_time = now;
        }
    }
};
