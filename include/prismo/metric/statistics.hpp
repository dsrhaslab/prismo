#ifndef PRISMO_METRIC_STATISTICS_H
#define PRISMO_METRIC_STATISTICS_H

#include <nlohmann/json.hpp>
#include <prismo/metric/metric.hpp>
#include <lib/distribution/aggregator.hpp>
#include <lib/distribution/percentile.hpp>

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
        Percentile::HDR percentile_hdr;

        Distribution::Aggregator<uint64_t, Distribution::ReduceOp::Sum> iops_aggr;
        Distribution::Aggregator<uint64_t, Distribution::ReduceOp::Sum> bw_aggr;
        Distribution::Aggregator<uint64_t, Distribution::ReduceOp::Average> lat_aggr;

        void record(const BaseMetric& metric) {
            total_ops++;
            total_bytes += metric.processed_bytes;

            uint64_t latency_ns = metric.end_ns - metric.start_ns;
            total_latency_ns += latency_ns;
            min_latency_ns = std::min(min_latency_ns, latency_ns);
            max_latency_ns = std::max(max_latency_ns, latency_ns);
            percentile_hdr.record(latency_ns);

            iops_aggr.record(1, metric.end_ns);
            bw_aggr.record(metric.processed_bytes, metric.end_ns);
            lat_aggr.record(latency_ns, metric.end_ns);
        }

        void merge(const OperationStats& other) {
            total_ops += other.total_ops;
            total_bytes += other.total_bytes;
            total_latency_ns += other.total_latency_ns;
            min_latency_ns = std::min(min_latency_ns, other.min_latency_ns);
            max_latency_ns = std::max(max_latency_ns, other.max_latency_ns);
            percentile_hdr.merge(other.percentile_hdr);
            iops_aggr.merge(other.iops_aggr);
            bw_aggr.merge(other.bw_aggr);
            lat_aggr.merge(other.lat_aggr);
        }

        void set_start_ns(uint64_t ns) {
            iops_aggr.start(ns);
            bw_aggr.start(ns);
            lat_aggr.start(ns);
        }

        void flush() {
            iops_aggr.flush();
            bw_aggr.flush();
            lat_aggr.flush();
        }

        nlohmann::json aggregations_json() const {
            return {
                {"iops", iops_aggr.values()},
                {"bandwidth_bytes_per_sec", bw_aggr.values()},
                {"avg_latency_ns_per_sex", lat_aggr.values()}
            };
        }

        nlohmann::json latency_json() const {
            return {
                {"min", total_ops > 0 ? min_latency_ns : 0},
                {"max", max_latency_ns},
                {"avg", total_ops > 0
                    ? total_latency_ns / total_ops : 0},
            };
        }

        nlohmann::json percentiles_json() const {
            return {
                {"p50", percentile_hdr.get_percentile(50.0)},
                {"p90", percentile_hdr.get_percentile(90.0)},
                {"p95", percentile_hdr.get_percentile(95.0)},
                {"p99", percentile_hdr.get_percentile(99.0)},
                {"p99_9", percentile_hdr.get_percentile(99.9)},
                {"p99_99", percentile_hdr.get_percentile(99.99)}
            };
        }
    };

    class Statistics {
        private:
            uint64_t start_ns;
            uint64_t end_ns;
            std::unordered_map<Operation::OperationType, OperationStats> stats_per_operation;

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
