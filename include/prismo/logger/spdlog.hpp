#ifndef PRISMO_LOGGER_SPDLOG_H
#define PRISMO_LOGGER_SPDLOG_H

#include <mutex>
#include <spdlog/spdlog.h>
#include <spdlog/async.h>
#include <spdlog/fmt/fmt.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/stdout_sinks.h>
#include <prismo/logger/logger.hpp>
#include <nlohmann/json.hpp>

namespace Logger {

    class Spdlog : public Base {
        private:
            inline static std::once_flag tp_flag;
            std::shared_ptr<spdlog::logger> logger;

        public:
            Spdlog() = delete;

            explicit Spdlog(const nlohmann::json& j);

            ~Spdlog() override {
                std::cout << "~Destroying Spdlog Logger" << std::endl;
            };

            void write(const Metric::Metric& metric) override;
        };
};

template<>
struct fmt::formatter<Metric::Metric> : fmt::formatter<std::string> {
    auto format(
        const Metric::Metric& metric,
        fmt::format_context& ctx
    ) const -> decltype(ctx.out());
};

#endif