#include <prismo/metric/statistics.hpp>

namespace Metric {

    void Statistics::start(void) {
        start_ns = get_current_timestamp();
        stats_per_operation.clear();
    }

    void Statistics::finish(void) {
        end_ns = get_current_timestamp();
        for (auto& [_, stats] : stats_per_operation) {
            stats.flush();
        }
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
                    auto [it, inserted] = stats_per_operation.try_emplace(m.operation_type);
                    if (inserted) {
                        it->second.set_start_ns(start_ns);
                    }
                    it->second.record(m);
                }
            },
            metric);
    }

    void Statistics::merge(const Statistics& other) {
        start_ns = std::min(start_ns, other.start_ns);
        end_ns = std::max(end_ns, other.end_ns);

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

        op_json["latency_ns"] = stats.latency_json();
        op_json["percentiles_ns"] = stats.percentiles_json();
        op_json["aggregations"] = stats.aggregations_json();

        return op_json;
    }

    nlohmann::json Statistics::to_json(void) const {
        nlohmann::json report;
        OperationStats combined;

        for (const auto& [_, stats] : stats_per_operation) {
            combined.merge(stats);
        }

        const double runtime_sec =
           static_cast<double>(end_ns - start_ns) / 1e9;

        report["total_operations"] = combined.total_ops;
        report["total_bytes"] = combined.total_bytes;
        report["runtime_sec"] = round_to(runtime_sec, 5);
        report["overall_iops"] = runtime_sec > 0.0
            ? round_to(combined.total_ops / runtime_sec) : 0;

        report["overall_bandwidth_bytes_per_sec"] = runtime_sec > 0.0
            ? round_to(combined.total_bytes / runtime_sec) : 0;

        report["overall_latency_ns"] = combined.latency_json();
        report["overall_percentiles_ns"] = combined.percentiles_json();
        report["overall_aggregations"] = combined.aggregations_json();

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
