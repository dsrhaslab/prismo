#include <prismo/io/statistics.h>
#include <sstream>
#include <iomanip>

namespace Metric {

    void Statistics::start() {
        start_time_ns = get_current_timestamp();
        started = true;
        finished = false;
        stats_per_operation.clear();
    }

    void Statistics::finish() {
        end_time_ns = get_current_timestamp();
        finished = true;
    }

    void Statistics::record_metric(const MetricVariant& metric) {
        std::visit([this](const auto& m) {
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
                stats_per_operation[m.operation_type].record(latency_ns, m.processed_bytes);
            }
        }, metric);
    }

    std::string Statistics::format_bytes(uint64_t bytes) const {
        std::ostringstream oss;
        oss << std::fixed << std::setprecision(2);

        if (bytes >= 1024ULL * 1024 * 1024 * 1024) {
            oss << (bytes / (1024.0 * 1024 * 1024 * 1024)) << " TiB";
        } else if (bytes >= 1024ULL * 1024 * 1024) {
            oss << (bytes / (1024.0 * 1024 * 1024)) << " GiB";
        } else if (bytes >= 1024ULL * 1024) {
            oss << (bytes / (1024.0 * 1024)) << " MiB";
        } else if (bytes >= 1024ULL) {
            oss << (bytes / 1024.0) << " KiB";
        } else {
            oss << bytes << " B";
        }

        return oss.str();
    }

    std::string Statistics::format_iops(double iops) const {
        std::ostringstream oss;
        oss << std::fixed << std::setprecision(2);

        if (iops >= 1000000) {
            oss << (iops / 1000000.0) << "M";
        } else if (iops >= 1000) {
            oss << (iops / 1000.0) << "k";
        } else {
            oss << iops;
        }

        return oss.str();
    }

    std::string Statistics::format_bandwidth(double bw_bytes_per_sec) const {
        std::ostringstream oss;
        oss << std::fixed << std::setprecision(2);

        if (bw_bytes_per_sec >= 1024.0 * 1024 * 1024) {
            oss << (bw_bytes_per_sec / (1024.0 * 1024 * 1024)) << " GiB/s";
        } else if (bw_bytes_per_sec >= 1024.0 * 1024) {
            oss << (bw_bytes_per_sec / (1024.0 * 1024)) << " MiB/s";
        } else if (bw_bytes_per_sec >= 1024.0) {
            oss << (bw_bytes_per_sec / 1024.0) << " KiB/s";
        } else {
            oss << bw_bytes_per_sec << " B/s";
        }

        return oss.str();
    }

    std::string Statistics::format_latency(uint64_t latency_ns) const {
        std::ostringstream oss;
        oss << std::fixed << std::setprecision(2);

        if (latency_ns >= 1000000000) {
            oss << (latency_ns / 1000000000.0) << " s";
        } else if (latency_ns >= 1000000) {
            oss << (latency_ns / 1000000.0) << " ms";
        } else if (latency_ns >= 1000) {
            oss << (latency_ns / 1000.0) << " us";
        } else {
            oss << latency_ns << " ns";
        }

        return oss.str();
    }

    void Statistics::print_operation_stats(
        std::ostream& os,
        const std::string& op_name,
        const OperationStats& stats,
        double runtime_sec
    ) const {
        if (stats.count == 0) return;

        double iops = runtime_sec > 0 ? stats.count / runtime_sec : 0;
        double bw = runtime_sec > 0 ? stats.total_bytes / runtime_sec : 0;

        os << "  " << op_name << ":\n";
        os << "    IOPS: " << format_iops(iops) << " (" << stats.count << " ops)\n";
        os << "    Bandwidth: " << format_bandwidth(bw)
           << " (" << format_bytes(stats.total_bytes) << " total)\n";

        os << "    Latency:\n";
        os << "      min: " << format_latency(stats.min_latency_ns) << "\n";
        os << "      avg: " << format_latency(stats.get_avg_latency_ns()) << "\n";
        os << "      max: " << format_latency(stats.max_latency_ns) << "\n";

        if (!stats.latencies.empty()) {
            OperationStats mutable_stats = stats;
            os << "    Percentiles:\n";
            os << "      50th: " << format_latency(mutable_stats.get_percentile(50.0)) << "\n";
            os << "      90th: " << format_latency(mutable_stats.get_percentile(90.0)) << "\n";
            os << "      95th: " << format_latency(mutable_stats.get_percentile(95.0)) << "\n";
            os << "      99th: " << format_latency(mutable_stats.get_percentile(99.0)) << "\n";
            os << "      99.9th: " << format_latency(mutable_stats.get_percentile(99.9)) << "\n";
            os << "      99.99th: " << format_latency(mutable_stats.get_percentile(99.99)) << "\n";
        }
    }

    void Statistics::print_report(std::ostream& os) const {
        double runtime_sec = static_cast<double>(end_time_ns - start_time_ns) / 1e9;

        os << "\n";
        os << "==================================================================\n";
        os << "                   Performance Statistics Report                  \n";
        os << "==================================================================\n";
        os << "\n";
        os << "Runtime: " << std::fixed << std::setprecision(3) << runtime_sec << " seconds\n";
        os << "\n";

        uint64_t total_ops = 0;
        uint64_t total_bytes = 0;

        for (const auto& [_, stats] : stats_per_operation) {
            total_ops += stats.count;
            total_bytes += stats.total_bytes;
        }

        os << "Total Operations: " << total_ops << "\n";
        os << "Total Data: " << format_bytes(total_bytes) << "\n";
        os << "\n";

        for (const auto& [op, stats]: stats_per_operation) {
            print_operation_stats(os, operation_to_str(op), stats, runtime_sec);
            os << "\n";
        }

        os << "==================================================================\n";
        os << "\n";
    }
}
