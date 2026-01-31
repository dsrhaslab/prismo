#include <prismo/parser/factory.h>

namespace Parser {

    std::unique_ptr<Generator::AccessGenerator> get_access_generator(const json& config) {
        std::string type = config.at("type").get<std::string>();
        std::unique_ptr<Generator::AccessGenerator> access_generator;

        if (type == "sequential") {
            access_generator = std::make_unique<Generator::SequentialAccessGenerator>(config);
        } else if (type == "random") {
            access_generator = std::make_unique<Generator::RandomAccessGenerator>(config);
        } else if (type == "zipfian") {
            access_generator = std::make_unique<Generator::ZipfianAccessGenerator>(config);
        } else if (type == "repeat") {
            access_generator = std::make_unique<Generator::RealisticRepeatGenerator>(config);
        } else {
            throw std::invalid_argument("get_access: type '" + type + "' not recognized");
        }

        access_generator->validate();
        return access_generator;
    }

    std::unique_ptr<Generator::OperationGenerator> get_operation_generator(const json& config) {
        std::string type = config.at("type").get<std::string>();
        std::unique_ptr<Generator::OperationGenerator> operation_generator;

        if (type == "constant") {
            operation_generator = std::make_unique<Generator::ConstantOperationGenerator>(config);
        } else if (type == "percentage") {
            operation_generator = std::make_unique<Generator::PercentageOperationGenerator>(config);
        } else if (type == "sequence") {
            operation_generator = std::make_unique<Generator::SequenceOperationGeneator>(config);
        } else if (type == "repeat") {
            operation_generator = std::make_unique<Generator::RealisticRepeatGenerator>(config);
        } else {
            throw std::invalid_argument("get_operation: type '" + type + "' not recognized");
        }

        operation_generator->validate();
        return operation_generator;
    }

    std::optional<Generator::MultipleBarrier> get_multiple_barrier(const json& config) {
        return config.contains("barrier")
            ? std::optional<Generator::MultipleBarrier>{config.at("barrier")}
            : std::nullopt;
    }

    std::optional<Generator::CompressionGenerator> get_compression_generator(const json& config) {
        std::optional<Generator::CompressionGenerator> compression_generator = std::nullopt;

        if (config.contains("compression")) {
            compression_generator = std::optional<Generator::CompressionGenerator>{config.at("compression")};
            compression_generator->validate();
        }

        return compression_generator;
    }

    std::unique_ptr<Generator::ContentGenerator> get_content_generator(const json& config) {
        std::string type = config.at("type").get<std::string>();
        std::unique_ptr<Generator::ContentGenerator> content_generator;

        if (type == "constant") {
            content_generator = std::make_unique<Generator::ConstantContentGenerator>();
        } else if (type == "random") {
            content_generator = std::make_unique<Generator::RandomContentGenerator>();
        } else if (type == "dedup") {
            content_generator = std::make_unique<Generator::DeduplicationContentGenerator>(config);
        } else {
            throw std::invalid_argument("get_generator: type '" + type + "' not recognized");
        }

        content_generator->validate();
        return content_generator;
    }

    std::unique_ptr<Logger::Logger> get_logger(const json& config) {
        const std::string type = config.at("type").get<std::string>();
        std::unique_ptr<Logger::Logger> logger;

        if (type == "spdlog") {
            logger = std::make_unique<Logger::Spdlog>(config);
        } else {
            throw std::invalid_argument("get_logger: type '" + type + "' not recognized");
        }

        return logger;
    }

    std::unique_ptr<Metric::Metric> get_metric(const json& config) {
        std::string type = config.at("metric").get<std::string>();
        std::unique_ptr<Metric::Metric> metric;

        if (type == "none") {
            metric = std::make_unique<Metric::NoneMetric>();
        } else if (type == "base") {
            metric = std::make_unique<Metric::BaseMetric>();
        } else if (type == "standard") {
            metric = std::make_unique<Metric::StandardMetric>();
        } else if (type == "full") {
            metric = std::make_unique<Metric::FullMetric>();
        } else {
            throw std::invalid_argument("get_metric: type '" + type + "' not recognized");
        }

        return metric;
    }

    std::unique_ptr<Engine::Engine> get_engine(
        const json& config,
        std::unique_ptr<Metric::Metric> metric,
        std::unique_ptr<Logger::Logger> logger
    ) {
        std::string type = config.at("type").get<std::string>();

        if (type == "posix") {
            return std::make_unique<Engine::PosixEngine>(
                std::move(metric),
                std::move(logger)
            );
        } else if (type == "uring") {
            return std::make_unique<Engine::UringEngine>(
                std::move(metric),
                std::move(logger),
                config.get<Engine::UringConfig>()
            );
        } else if (type == "aio") {
            return std::make_unique<Engine::AioEngine>(
                std::move(metric),
                std::move(logger),
                config.get<Engine::AioConfig>()
            );
        } else if (type == "spdk") {
            return std::make_unique<Engine::SpdkEngine>(
                std::move(metric),
                std::move(logger),
                config.get<Engine::SpdkConfig>()
            );
        } else {
            throw std::invalid_argument("get_engine: type '" + type + "' not recognized");
        }
    }
}