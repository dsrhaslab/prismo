#include <prismo/logger/spdlog.h>

namespace Logger {

    Spdlog::Spdlog(const SpdlogConfig& config) : Logger() {
        std::vector<spdlog::sink_ptr> sinks;
        spdlog::init_thread_pool(config.queue_size, config.thread_count);

        if (config.to_stdout) {
            auto stdout_sink = std::make_shared<spdlog::sinks::stdout_sink_mt>();
            sinks.push_back(stdout_sink);
        }

        for (auto& file : config.files) {
            auto file_sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(file, config.truncate);
            sinks.push_back(file_sink);
        }

        logger = std::make_shared<spdlog::async_logger>(
            config.name,
            sinks.begin(),
            sinks.end(),
            spdlog::thread_pool(),
            spdlog::async_overflow_policy::block
        );

        spdlog::register_logger(logger);
    }

    Spdlog::~Spdlog() {
        std::cout << "~Destroying Spdlog" << std::endl;
    }

    void Spdlog::info(Metric::Metric& metric) {
        switch (metric.type) {
            case Metric::MetricType::None:
                break;
            case Metric::MetricType::Base:
                logger->info(static_cast<Metric::BaseMetric&>(metric));
                break;
            case Metric::MetricType::Standard:
                logger->info(static_cast<Metric::StandardMetric&>(metric));
                break;
            case Metric::MetricType::Full:
                logger->info(static_cast<Metric::FullMetric&>(metric));
                break;
        }
    }

    void from_json(const json& j, SpdlogConfig& config) {
        config.name         = j.at("name").get<std::string>();
        config.queue_size   = j.at("queue_size").get<size_t>();
        config.thread_count = j.at("thread_count").get<size_t>();
        config.truncate     = j.at("truncate").get<bool>();
        config.to_stdout    = j.at("to_stdout").get<bool>();
        config.files        = j.at("files").get<std::vector<std::string>>();
    };
};

auto fmt::formatter<Metric::BaseMetric>::format(
    const Metric::BaseMetric metric,
    fmt::format_context& ctx
) const -> decltype(ctx.out()) {
    return fmt::format_to(
        ctx.out(),
        "[type={} block={:016x} cpr={} sts={} ets={}]",
        static_cast<uint8_t>(metric.operation_type),
        metric.block_id,
        metric.compression,
        metric.start_timestamp,
        metric.end_timestamp
    );
}

auto fmt::formatter<Metric::StandardMetric>::format(
    const Metric::StandardMetric metric,
    fmt::format_context& ctx
) const -> decltype(ctx.out()) {
    return fmt::format_to(
        ctx.out(),
        "[type={} block={:016x} cpr={} sts={} ets={} pid={} tid={}]",
        static_cast<uint8_t>(metric.operation_type),
        metric.block_id,
        metric.compression,
        metric.start_timestamp,
        metric.end_timestamp,
        metric.pid,
        metric.tid
    );
}

auto fmt::formatter<Metric::FullMetric>::format(
    const Metric::FullMetric metric,
    fmt::format_context& ctx
) const -> decltype(ctx.out()) {
    return fmt::format_to(
        ctx.out(),
        "[type={} block={:016x} cpr={} sts={} ets={} pid={} tid={} req={} proc={} offset={} ret={} errno={}]",
        static_cast<uint8_t>(metric.operation_type),
        metric.block_id,
        metric.compression,
        metric.start_timestamp,
        metric.end_timestamp,
        metric.pid,
        metric.tid,
        metric.requested_bytes,
        metric.processed_bytes,
        metric.offset,
        metric.return_code,
        metric.error_no
    );
}