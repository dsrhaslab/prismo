#include <prismo/logger/spdlog.h>

namespace Logger {

    Spdlog::Spdlog(const json& j) : Logger() {
        std::vector<spdlog::sink_ptr> sinks;
        spdlog::init_thread_pool(
            j.at("queue_size").get<size_t>(),
            j.at("thread_count").get<size_t>()
        );

        if (j.at("to_stdout").get<bool>()) {
            auto stdout_sink = std::make_shared<spdlog::sinks::stdout_sink_mt>();
            sinks.push_back(stdout_sink);
        }

        for (auto& file : j.at("files").get<std::vector<std::string>>()) {
            auto file_sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>
                (file, j.at("truncate").get<bool>());
            sinks.push_back(file_sink);
        }

        logger = std::make_shared<spdlog::async_logger>(
            j.at("name").get<std::string>(),
            sinks.begin(),
            sinks.end(),
            spdlog::thread_pool(),
            spdlog::async_overflow_policy::block
        );

        spdlog::register_logger(logger);
    }

    void Spdlog::info(const Metric::MetricVariant& metric) {
        std::visit([this](const auto& m) {
            using T = std::decay_t<decltype(m)>;
            if constexpr (!std::is_same_v<T, Metric::NoneMetric>) {
                logger->info(m);
            }
        }, metric);
    }
};

auto fmt::formatter<Metric::BaseMetric>::format(
    const Metric::BaseMetric& metric,
    fmt::format_context& ctx
) const -> decltype(ctx.out()) {
    return fmt::format_to(
        ctx.out(),
        "[type={} block={:016x} cpr={} sts={} ets={} proc={}]",
        static_cast<uint8_t>(metric.operation_type),
        metric.block_id,
        metric.compression,
        metric.start_ns,
        metric.end_ns,
        metric.processed_bytes
    );
}

auto fmt::formatter<Metric::StandardMetric>::format(
    const Metric::StandardMetric& metric,
    fmt::format_context& ctx
) const -> decltype(ctx.out()) {
    return fmt::format_to(
        ctx.out(),
        "[type={} block={:016x} cpr={} sts={} ets={} proc={} pid={} tid={}]",
        static_cast<uint8_t>(metric.operation_type),
        metric.block_id,
        metric.compression,
        metric.start_ns,
        metric.end_ns,
        metric.processed_bytes,
        metric.pid,
        metric.tid
    );
}

auto fmt::formatter<Metric::FullMetric>::format(
    const Metric::FullMetric& metric,
    fmt::format_context& ctx
) const -> decltype(ctx.out()) {
    return fmt::format_to(
        ctx.out(),
        "[type={} block={:016x} cpr={} sts={} ets={} pid={} tid={} req={} proc={} offset={} ret={} errno={}]",
        static_cast<uint8_t>(metric.operation_type),
        metric.block_id,
        metric.compression,
        metric.start_ns,
        metric.end_ns,
        metric.pid,
        metric.tid,
        metric.requested_bytes,
        metric.processed_bytes,
        metric.offset,
        metric.return_code,
        metric.error_no
    );
}