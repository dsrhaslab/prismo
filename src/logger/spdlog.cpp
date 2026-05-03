#include <prismo/logger/spdlog.hpp>

namespace Logger {

    Spdlog::Spdlog(const nlohmann::json& j) : Base(j) {
        std::string logger_name = fmt::format("{}-job{}",
            j.at("name").get<std::string>(),
            j.at("worker_id").get<int>()
        );

        std::vector<spdlog::sink_ptr> sinks;

        std::call_once(Spdlog::tp_flag, [&]() {
            spdlog::init_thread_pool(
                j.at("queue_size").get<size_t>(),
                j.at("thread_count").get<size_t>()
            );
        });

        if (j.at("to_stdout").get<bool>()) {
            auto stdout_sink = std::make_shared<spdlog::sinks::stdout_sink_mt>();
            sinks.push_back(stdout_sink);
        }

        for (auto& file : j.at("files").get<std::vector<std::string>>()) {
            file = fmt::format("{}-job{}", file, j.at("worker_id").get<int>());
            auto file_sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>
                (file, j.at("truncate").get<bool>());
            sinks.push_back(file_sink);
        }

        logger = std::make_shared<spdlog::async_logger>(
            logger_name,
            sinks.begin(),
            sinks.end(),
            spdlog::thread_pool(),
            spdlog::async_overflow_policy::block
        );

        spdlog::register_logger(logger);
    }

    void Spdlog::write(const Metric::Metric& metric) {
        logger->info(metric);
    }
};

auto fmt::formatter<Metric::Metric>::format(
    const Metric::Metric& metric,
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