#ifndef PRISMO_METRIC_STATISTICS_H
#define PRISMO_METRIC_STATISTICS_H

#include <map>
#include <nlohmann/json.hpp>
#include <prismo/metric/metric.h>
#include <common/percentile.h>

namespace Metric {

    struct OperationStats {
        private:
            uint64_t count = 0;
            uint64_t total_bytes = 0;
            uint64_t total_latency_ns = 0;
            uint64_t min_latency_ns = UINT64_MAX;
            uint64_t max_latency_ns = 0;
            Percentile::Calculator percentile_calc;

        public:
            bool has_data(void) const {
                return count > 0;
            }

            uint64_t get_count(void) const {
                return count;
            }

            uint64_t get_total_bytes(void) const {
                return total_bytes;
            }

            uint64_t get_min_latency_ns(void) const {
                return min_latency_ns;
            }

            uint64_t get_max_latency_ns(void) const {
                return max_latency_ns;
            }

            uint64_t get_avg_latency_ns(void) const {
                return count > 0 ? total_latency_ns / count : 0;
            }

            uint64_t get_percentile(double percentile) const {
                return percentile_calc.get_percentile(percentile);
            }

            double get_iops(double runtime_sec) const {
                return runtime_sec > 0 ? count / runtime_sec : 0;
            }

            double get_bandwidth(double runtime_sec) const {
                return runtime_sec > 0 ? total_bytes / runtime_sec : 0;
            }

            void record(uint64_t latency_ns, uint64_t bytes) {
                count++;
                total_bytes += bytes;
                total_latency_ns += latency_ns;
                min_latency_ns = std::min(min_latency_ns, latency_ns);
                max_latency_ns = std::max(max_latency_ns, latency_ns);
                percentile_calc.record(latency_ns);
            }
    };

    class Statistics {
        private:
            bool started;
            bool finished;

            uint64_t start_time_ns;
            uint64_t end_time_ns;

            std::map<Operation::OperationType, OperationStats> stats_per_operation;

        public:
            Statistics() = default;

            ~Statistics() {
                std::cout << "~Destroying Statistics" << std::endl;
            };

            void start(void);
            void finish(void);

            void record_metric(const MetricVariant& metric);
            nlohmann::json get_report_json(void) const;

        private:
            static double round_to(double value, int precision = 2) {
                const double scale = std::pow(10.0, precision);
                return std::round(value * scale) / scale;
            }

            nlohmann::json get_operation_stats_json(
                const std::string& op_name,
                const OperationStats& stats,
                double runtime_sec
            ) const;
    };
}

#endif
