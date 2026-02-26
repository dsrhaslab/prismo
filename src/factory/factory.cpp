#include <prismo/factory/factory.h>

namespace Factory {

    std::unique_ptr<Generator::Extension::TraceExtension> get_trace_extension(
        const nlohmann::json& config
    ) {
        std::string type = config.value("extension", "repeat");
        std::unique_ptr<Generator::Extension::TraceExtension> extension;

        if (type == "repeat") {
            extension = std::make_unique<Generator::Extension::RepeatExtension>(config);
        } else if (type == "sample") {
            extension = std::make_unique<Generator::Extension::SampleExtension>(config);
        } else {
            throw std::invalid_argument(
                "get_trace_extension: type '" + type + "' not recognized");
        }

        return extension;
    }

    std::unique_ptr<Generator::AccessGenerator> get_access_generator(
        const nlohmann::json& config
    ) {
        std::string type = config.value("type", "sequential");
        std::unique_ptr<Generator::AccessGenerator> access_generator;

        if (type == "sequential") {
            access_generator =
                std::make_unique<Generator::SequentialAccessGenerator>(config);
        } else if (type == "random") {
            access_generator =
                std::make_unique<Generator::RandomAccessGenerator>(config);
        } else if (type == "zipfian") {
            access_generator =
                std::make_unique<Generator::ZipfianAccessGenerator>(config);
        } else if (type == "trace") {
            access_generator =
                std::make_unique<Generator::TraceBasedAccessGenerator>(
                    config, get_trace_extension(config));
        } else {
            throw std::invalid_argument(
                "get_access_generator: type '" + type + "' not recognized");
        }

        return access_generator;
    }

    std::unique_ptr<Generator::OperationGenerator> get_operation_generator(
        const nlohmann::json& config
    ) {
        std::string type = config.value("type", "constant");
        std::unique_ptr<Generator::OperationGenerator> operation_generator;

        if (type == "constant") {
            operation_generator =
                std::make_unique<Generator::ConstantOperationGenerator>(config);
        } else if (type == "percentage") {
            operation_generator =
                std::make_unique<Generator::PercentageOperationGenerator>(config);
        } else if (type == "sequence") {
            operation_generator =
                std::make_unique<Generator::SequenceOperationGenerator>(config);
        } else if (type == "trace") {
            operation_generator =
                std::make_unique<Generator::TraceBasedOperationGenerator>(
                    get_trace_extension(config));
        } else {
            throw std::invalid_argument(
                "get_operation_generator: type '" + type + "' not recognized");
        }

        return operation_generator;
    }

    std::unique_ptr<Generator::ContentGenerator> get_content_generator(
        const nlohmann::json& config
    ) {
        std::string type = config.value("type", "constant");
        std::unique_ptr<Generator::ContentGenerator> content_generator;

        if (type == "constant") {
            content_generator =
                std::make_unique<Generator::ConstantContentGenerator>(config);
        } else if (type == "random") {
            content_generator =
                std::make_unique<Generator::RandomContentGenerator>(config);
        } else if (type == "dedup") {
            content_generator =
                std::make_unique<Generator::DeduplicationContentGenerator>(config);
        } else if (type == "trace") {
            content_generator =
                std::make_unique<Generator::TraceBasedContentGenerator>(
                    config, get_trace_extension(config));
        } else {
            throw std::invalid_argument(
                "get_content_generator: type '" + type + "' not recognized");
        }

        return content_generator;
    }

    std::optional<Generator::MultipleBarrier> get_multiple_barrier(
        const nlohmann::json& config
    ) {
        return config.contains("barrier")
            ? std::optional<Generator::MultipleBarrier>{config.at("barrier")}
            : std::nullopt;
    }

    std::optional<Generator::CompressionGenerator> get_compression_generator(
        const nlohmann::json& config
    ) {
        return config.contains("compression")
            ? std::optional<Generator::CompressionGenerator>{config.at("compression")}
            : std::nullopt;
    }

    std::optional<Worker::Ramp> get_ramp(
        const nlohmann::json& config
    ) {
        return config.contains("ramp")
            ? std::optional<Worker::Ramp>{config.at("ramp")}
            : std::nullopt;
    }

    std::shared_ptr<Logger::Base> get_logger(const nlohmann::json& config) {
        const std::string type = config.value("type", "null");

        if (type == "spdlog") {
            return std::make_shared<Logger::Spdlog>(config);
        } else if (type != "null") {
            throw std::invalid_argument(
                "get_logger: type '" + type + "' not recognized");
        }

        return nullptr;
    }

    Metric::MetricVariant get_metric(
        const nlohmann::json& config
    ) {
        std::string type = config.value("metric", "base");

        if (type == "none") {
            return Metric::NoneMetric{};
        } else if (type == "base") {
            return Metric::BaseMetric{};
        } else if (type == "standard") {
            return Metric::StandardMetric{};
        } else if (type == "full") {
            return Metric::FullMetric{};
        } else {
            throw std::invalid_argument(
                "get_metric: type '" + type + "' not recognized");
        }
    }

    std::unique_ptr<Engine::Base> get_engine(
        const nlohmann::json& config,
        Metric::MetricVariant metric,
        std::shared_ptr<Logger::Base> logger
    ) {
        std::string type = config.value("type", "posix");

        if (type == "posix") {
            return std::make_unique<Engine::PosixEngine>(
                std::move(metric),
                logger
            );
        } else if (type == "uring") {
            return std::make_unique<Engine::UringEngine>(
                std::move(metric),
                logger,
                config.get<Engine::UringConfig>()
            );
        } else if (type == "aio") {
            return std::make_unique<Engine::AioEngine>(
                std::move(metric),
                logger,
                config.get<Engine::AioConfig>()
            );
        } else if (type == "spdk") {
            return std::make_unique<Engine::SpdkEngine>(
                std::move(metric),
                logger,
                config.get<Engine::SpdkConfig>()
            );
        } else {
            throw std::invalid_argument(
                "get_engine: type '" + type + "' not recognized");
        }
    }
}