#ifndef PRISMO_METRIC_STATISTICS_H
#define PRISMO_METRIC_STATISTICS_H

#include <map>
#include <nlohmann/json.hpp>
#include <prismo/metric/metric.hpp>
#include <common/percentile.hpp>

namespace Metric {

    inline double round_to(double value, int precision = 2) {
        const double scale = std::pow(10.0, precision);
        return std::round(value * scale) / scale;
    }

    struct OperationStats {
        uint64_t total_ops = 0;
        uint64_t total_bytes = 0;
        uint64_t total_latency_ns = 0;
        uint64_t min_latency_ns = UINT64_MAX;
        uint64_t max_latency_ns = 0;
        Percentile::Calculator percentile_calc;

        void record(uint64_t latency_ns, uint64_t bytes) {
            total_ops++;
            total_bytes += bytes;
            total_latency_ns += latency_ns;
            min_latency_ns = std::min(min_latency_ns, latency_ns);
            max_latency_ns = std::max(max_latency_ns, latency_ns);
            percentile_calc.record(latency_ns);
        }

        void merge(const OperationStats& other) {
            total_ops += other.total_ops;
            total_bytes += other.total_bytes;
            total_latency_ns += other.total_latency_ns;
            min_latency_ns = std::min(min_latency_ns, other.min_latency_ns);
            max_latency_ns = std::max(max_latency_ns, other.max_latency_ns);
            percentile_calc.merge(other.percentile_calc);
        }
    };

    class Statistics {
        private:
            uint64_t start_time_ns = UINT64_MAX;
            uint64_t end_time_ns = 0;

            std::map<Operation::OperationType, OperationStats> stats_per_operation;

        public:
            Statistics() = default;

            ~Statistics() {
                std::cout << "~Destroying Statistics" << std::endl;
            };

            void start(void);
            void finish(void);

            void record_metric(const MetricVariant& metric);
            void merge(const Statistics& other);

            nlohmann::json to_json(void) const;

        private:
            nlohmann::json get_operation_stats_json(
                const std::string& op_name,
                const OperationStats& stats,
                double runtime_sec
            ) const;
    };
}

#endif
