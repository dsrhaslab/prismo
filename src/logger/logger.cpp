#include <prismo/logger/logger.hpp>

namespace Logger {

    Base::Base(const nlohmann::json& j)
        : avg_interval_ms(j.value("avg_interval_ms", 1000)),
          last_avg_time(std::chrono::steady_clock::now()) {}

    Base::~Base() {
        std::cout << "~Destroying Logger" << std::endl;
    }

    Metric::Metric Base::merge(const std::vector<Metric::Metric>& metrics) const {
        Metric::Metric merged{
            .operation_type = Operation::OperationType::READ,
            .block_id = 0,
            .compression = 0,
            .start_ns = UINT64_MAX,
            .end_ns = 0,
            .pid = 0,
            .tid = 0,
            .requested_bytes = 0,
            .processed_bytes = 0,
            .offset = 0,
            .return_code = 0,
            .error_no = 0
        };

        for (const auto& m : metrics) {
            merged.start_ns = std::min(merged.start_ns, m.start_ns);
            merged.end_ns = std::max(merged.end_ns, m.end_ns);
            merged.processed_bytes += m.processed_bytes;
            merged.requested_bytes += m.requested_bytes;
        }

        merged.operation_type = metrics.front().operation_type;
        merged.pid = metrics.front().pid;
        merged.tid = metrics.front().tid;

        return merged;
    }

    void Base::flush(void) {
        for (auto& [op_type, op_metrics] : metrics_by_op) {
            if (!op_metrics.empty()) {
                Metric::Metric merged_metric = merge(op_metrics);
                write(merged_metric);
                op_metrics.clear();
            }
        }
        last_avg_time = std::chrono::steady_clock::now();
    }

    void Base::info(const Metric::Metric& metric) {
        metrics_by_op[metric.operation_type].push_back(metric);

        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - last_avg_time
        ).count();

        if (static_cast<uint64_t>(elapsed) >= avg_interval_ms) {
            flush();
        }
    }
};
