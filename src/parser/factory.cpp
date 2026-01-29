#include <prismo/parser/factory.h>

namespace Parser {

    std::unique_ptr<Generator::AccessGenerator> get_access_generator(const json& config) {
        std::string type = config.at("type").get<std::string>();

        if (type == "sequential") {
            return std::make_unique<Generator::SequentialAccessGenerator>(
                config.get<Generator::SequentialAccessGenerator>()
            );
        } else if (type == "random") {
            return std::make_unique<Generator::RandomAccessGenerator>(
                config.get<Generator::RandomAccessGenerator>()
            );
        } else if (type == "zipfian") {
            return std::make_unique<Generator::ZipfianAccessGenerator>(
                config.get<Generator::ZipfianAccessGenerator>()
            );
        } else {
            throw std::invalid_argument("get_access: type '" + type + "' not recognized");
        }
    }

    std::unique_ptr<Generator::ContentGenerator> get_content_generator(const json& config) {
        std::string type = config.at("type").get<std::string>();

        if (type == "constant") {
            return std::make_unique<Generator::ConstantContentGenerator>();
        } else if (type == "random") {
            return std::make_unique<Generator::RandomContentGenerator>();
        } else if (type == "dedup") {
            return std::make_unique<Generator::DeduplicationContentGenerator>(
                config.get<Generator::DeduplicationContentGeneratorConfig>()
            );
        } else {
            throw std::invalid_argument("get_generator: type '" + type + "' not recognized");
        }
    }

    std::unique_ptr<Generator::OperationGenerator> get_operation_generator(const json& config) {
        std::string type = config.at("type").get<std::string>();

        if (type == "constant") {
            return std::make_unique<Generator::ConstantOperationGenerator>(
                config.get<Generator::ConstantOperationGenerator>()
            );
        } else if (type == "percentage") {
            return std::make_unique<Generator::PercentageOperationGenerator>(
                config.get<Generator::PercentageOperationGenerator>()
            );
        } else if (type == "sequence") {
            return std::make_unique<Generator::SequenceOperationGeneator>(
                config.get<Generator::SequenceOperationGeneator>()
            );
        } else {
            throw std::invalid_argument("get_operation: type '" + type + "' not recognized");
        }
    }

    std::unique_ptr<Generator::MultipleBarrier> get_multiple_barrier(const json& config) {
        return std::make_unique<Generator::MultipleBarrier>(
            config.get<Generator::MultipleBarrier>()
        );
    }

    std::unique_ptr<Metric::Metric> get_metric(const json& config) {
        std::string type = config.at("metric").get<std::string>();

        if (type == "none") {
            return std::make_unique<Metric::NoneMetric>();
        } else if (type == "base") {
            return std::make_unique<Metric::BaseMetric>();
        } else if (type == "standard") {
            return std::make_unique<Metric::StandardMetric>();
        } else if (type == "full") {
            return std::make_unique<Metric::FullMetric>();
        } else {
            throw std::invalid_argument("get_metric: type '" + type + "' not recognized");
        }
    }

    std::unique_ptr<Logger::Logger> get_logger(const json& config) {
        const std::string type = config.at("type").get<std::string>();

        if (type == "spdlog") {
            return std::make_unique<Logger::Spdlog>(
                config.get<Logger::SpdlogConfig>()
            );
        } else {
            throw std::invalid_argument("get_logger: type '" + type + "' not recognized");
        }
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