#include <prismo/metric/statistics.hpp>

namespace Metric {

    void Statistics::start(void) {
        start_time_ns = get_current_timestamp();
        stats_per_operation.clear();
    }

    void Statistics::finish(void) {
        end_time_ns = get_current_timestamp();
    }

    void Statistics::record_metric(const MetricVariant& metric) {
        std::visit(
            [this](const auto& m) {
                using T = std::decay_t<decltype(m)>;

                if constexpr (
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

    void Statistics::merge(const Statistics& other) {
        start_time_ns = std::min(start_time_ns, other.start_time_ns);
        end_time_ns = std::max(end_time_ns, other.end_time_ns);

        for (const auto& [op, other_stats] : other.stats_per_operation) {
            stats_per_operation[op].merge(other_stats);
        }
    }

    nlohmann::json Statistics::get_operation_stats_json(
        const std::string& op_name,
        const OperationStats& stats,
        double runtime_sec
    ) const {
        nlohmann::json op_json;

        op_json["operation"] = op_name;
        op_json["count"] = stats.total_ops;
        op_json["total_bytes"] = stats.total_bytes;
        op_json["iops"] = runtime_sec > 0.0
            ? round_to(stats.total_ops / runtime_sec) : 0;

        op_json["bandwidth_bytes_per_sec"] = runtime_sec > 0.0
            ? round_to(stats.total_bytes / runtime_sec) : 0;

        op_json["latency_ns"] = {
            {"min", stats.min_latency_ns},
            {"max", stats.max_latency_ns},
            {"avg", stats.total_ops > 0
                ? stats.total_latency_ns / stats.total_ops : 0
            },
        };

        op_json["percentiles_ns"] = {
            {"p50", stats.percentile_calc.get_percentile(50.0)},
            {"p90", stats.percentile_calc.get_percentile(90.0)},
            {"p95", stats.percentile_calc.get_percentile(95.0)},
            {"p99", stats.percentile_calc.get_percentile(99.0)},
            {"p99_9", stats.percentile_calc.get_percentile(99.9)},
            {"p99_99", stats.percentile_calc.get_percentile(99.99)}
        };

        return op_json;
    }

    nlohmann::json Statistics::to_json(void) const {
        nlohmann::json report;
        uint64_t total_operations = 0;
        uint64_t total_bytes = 0;

        for (const auto& [_, stats] : stats_per_operation) {
            total_operations += stats.total_ops;
            total_bytes += stats.total_bytes;
        }

        const double runtime_sec =
           static_cast<double>(end_time_ns - start_time_ns) / 1e9;

        report["total_operations"] = total_operations;
        report["total_bytes"] = total_bytes;
        report["runtime_sec"] = round_to(runtime_sec, 5);
        report["overall_iops"] = runtime_sec > 0.0
            ? round_to(total_operations / runtime_sec) : 0;

        report["overall_bandwidth_bytes_per_sec"] = runtime_sec > 0.0
            ? round_to(total_bytes / runtime_sec) : 0;

        if (!stats_per_operation.empty()) {
            report["operations"] = nlohmann::json::array();
        }

        for (const auto& [op, stats] : stats_per_operation) {
            report["operations"].push_back(get_operation_stats_json(
                operation_to_str(op), stats, runtime_sec));
        }

        return report;
    }
}
