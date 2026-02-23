#ifndef IO_STATISTICS_H
#define IO_STATISTICS_H

#include <map>
#include <cmath>
#include <numeric>
#include <iostream>
#include <prismo/io/metric.h>

namespace Metric {

    struct OperationStats {
        uint64_t count = 0;
        uint64_t total_bytes = 0;
        uint64_t total_latency_ns = 0;
        uint64_t min_latency_ns = UINT64_MAX;
        uint64_t max_latency_ns = 0;
        std::vector<uint64_t> latencies;

        void record(uint64_t latency_ns, uint64_t bytes) {
            count++;
            total_bytes += bytes;
            total_latency_ns += latency_ns;
            min_latency_ns = std::min(min_latency_ns, latency_ns);
            max_latency_ns = std::max(max_latency_ns, latency_ns);
            latencies.push_back(latency_ns);
        }

        uint64_t get_avg_latency_ns() const {
            return std::accumulate(
                latencies.begin(), latencies.end(), uint64_t{0}) /
                latencies.size();
        }

        uint64_t get_percentile(double percentile) {
            std::sort(latencies.begin(), latencies.end());
            size_t index = static_cast<size_t>(
                std::ceil(percentile * latencies.size() / 100.0)
            ) - 1;

            if (index >= latencies.size()) {
                index = latencies.size() - 1;
            }

            return latencies.empty() ? 0 : latencies[index];
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

         ~Statistics() { std::cout << "~Destroying Statistics" << std::endl; };

         void start();
         void finish();

         void record_metric(const MetricVariant& metric);
         void print_report(std::ostream& os = std::cout) const;

        private:
            std::string format_bytes(uint64_t bytes) const;
            std::string format_iops(double iops) const;
            std::string format_bandwidth(double bw_bytes_per_sec) const;
            std::string format_latency(uint64_t latency_ns) const;

            void print_operation_stats(
                std::ostream& os,
                const std::string& op_name,
                const OperationStats& stats,
                double runtime_sec
            ) const;
    };
}

#endif