#ifndef SPDLOG_LOGGER_H
#define SPDLOG_LOGGER_H

#include <spdlog/spdlog.h>
#include <spdlog/async.h>
#include <spdlog/fmt/fmt.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/stdout_sinks.h>
#include <prismo/logger/logger.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace Logger {

    struct SpdlogConfig {
        std::string name;
        size_t queue_size;
        size_t thread_count;
        bool truncate;
        bool to_stdout;
        std::vector<std::string> files;
    };

    class Spdlog : public Logger {
        private:
            std::shared_ptr<spdlog::logger> logger;

        public:
            Spdlog(const SpdlogConfig& config);
            ~Spdlog() override;

            void info(Metric::Metric& metric) override;
        };

    void from_json(const json& j, SpdlogConfig& config);
};

template<>
struct fmt::formatter<Metric::BaseMetric> : fmt::formatter<std::string> {
    auto format(
        const Metric::BaseMetric metric,
        fmt::format_context& ctx
    ) const -> decltype(ctx.out());
};

template<>
struct fmt::formatter<Metric::StandardMetric> : fmt::formatter<std::string> {
    auto format(
        const Metric::StandardMetric metric,
        fmt::format_context& ctx
    ) const -> decltype(ctx.out());
};

template<>
struct fmt::formatter<Metric::FullMetric> : fmt::formatter<std::string> {
    auto format(
        const Metric::FullMetric metric,
        fmt::format_context& ctx
    ) const -> decltype(ctx.out());
};

#endif