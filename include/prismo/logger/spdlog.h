#ifndef PRISMO_LOGGER_SPDLOG_H
#define PRISMO_LOGGER_SPDLOG_H

#include <spdlog/spdlog.h>
#include <spdlog/async.h>
#include <spdlog/fmt/fmt.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/stdout_sinks.h>
#include <prismo/logger/logger.h>
#include <nlohmann/json.hpp>

namespace Logger {

    class Spdlog : public Base {
        private:
            std::shared_ptr<spdlog::logger> logger;

        public:
            Spdlog() = delete;

            ~Spdlog() override {
                std::cout << "~Destroying Spdlog Logger" << std::endl;
            };

            explicit Spdlog(const nlohmann::json& j);

            void info(const Metric::MetricVariant& metric) override;
        };
};

template<>
struct fmt::formatter<Metric::BaseMetric> : fmt::formatter<std::string> {
    auto format(
        const Metric::BaseMetric& metric,
        fmt::format_context& ctx
    ) const -> decltype(ctx.out());
};

template<>
struct fmt::formatter<Metric::StandardMetric> : fmt::formatter<std::string> {
    auto format(
        const Metric::StandardMetric& metric,
        fmt::format_context& ctx
    ) const -> decltype(ctx.out());
};

template<>
struct fmt::formatter<Metric::FullMetric> : fmt::formatter<std::string> {
    auto format(
        const Metric::FullMetric& metric,
        fmt::format_context& ctx
    ) const -> decltype(ctx.out());
};

#endif