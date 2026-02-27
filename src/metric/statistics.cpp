#include <prismo/metric/statistics.hpp>

namespace Metric {

    void Statistics::start(void) {
        start_time_ns = get_current_timestamp();
        started = true;
        finished = false;
        stats_per_operation.clear();
    }

    void Statistics::finish(void) {
        end_time_ns = get_current_timestamp();
        finished = true;
    }

    void Statistics::record_metric(const MetricVariant& metric) {
        std::visit(
            [this](const auto& m) {
                using T = std::decay_t<decltype(m)>;

                if constexpr (std::is_same_v<T, NoneMetric>) {
                    return;
                }

                else if constexpr (
                    std::is_same_v<T, BaseMetric> ||
                    std::is_same_v<T, StandardMetric> ||
                    std::is_same_v<T, FullMetric>
                ) {
                    uint64_t latency_ns = m.end_ns - m.start_ns;
                    stats_per_operation[m.operation_type].record(
                        latency_ns, m.processed_bytes);
                }
            },
            metric);
    }

    nlohmann::json Statistics::get_operation_stats_json(
        const std::string& op_name,
        const OperationStats& stats,
        double runtime_sec
    ) const {
        nlohmann::json op_json;

        op_json["operation"] = op_name;
        op_json["count"] = stats.get_count();
        op_json["total_bytes"] = stats.get_total_bytes();
        op_json["iops"] = Statistics::round_to(stats.get_iops(runtime_sec));
        op_json["bandwidth_bytes_per_sec"] =
            Statistics::round_to(stats.get_bandwidth(runtime_sec));

        op_json["latency_ns"] = {
            {"min", stats.get_min_latency_ns()},
            {"avg", stats.get_avg_latency_ns()},
            {"max", stats.get_max_latency_ns()}
        };

        op_json["percentiles_ns"] = {
            {"p50", stats.get_percentile(50.0)},
            {"p90", stats.get_percentile(90.0)},
            {"p95", stats.get_percentile(95.0)},
            {"p99", stats.get_percentile(99.0)},
            {"p99_9", stats.get_percentile(99.9)},
            {"p99_99", stats.get_percentile(99.99)}
        };

        return op_json;
    }

    nlohmann::json Statistics::get_report_json(void) const {
        nlohmann::json report;
        uint64_t total_ops = 0;
        uint64_t total_bytes = 0;

        const double runtime_sec =
           static_cast<double>(end_time_ns - start_time_ns) / 1e9;

        for (const auto& [_, stats] : stats_per_operation) {
            total_ops += stats.get_count();
            total_bytes += stats.get_total_bytes();
        }

        report["total_operations"] = total_ops;
        report["total_bytes"] = total_bytes;
        report["runtime_sec"] = Statistics::round_to(runtime_sec, 5);
        report["overall_iops"] =
            runtime_sec > 0 ? Statistics::round_to(total_ops / runtime_sec) : 0;

        report["overall_bandwidth_bytes_per_sec"] =
            runtime_sec > 0 ? Statistics::round_to(total_bytes / runtime_sec) : 0;

        if (total_ops > 0) {
            report["operations"] = nlohmann::json::array();
            for (const auto& [op, stats] : stats_per_operation) {
                report["operations"].push_back(get_operation_stats_json(
                    operation_to_str(op), stats, runtime_sec));
            }
        }

        return report;
    }
}
