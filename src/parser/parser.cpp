#include <parser/parser.h>

namespace Parser {

    std::unique_ptr<Access::Access> get_access(const json& config) {
        std::string type = config.at("type").get<std::string>();

        if (type == "sequential") {
            return std::make_unique<Access::SequentialAccess>(
                config.get<Access::SequentialAccess>()
            );
        } else if (type == "random") {
            return std::make_unique<Access::RandomAccess>(
                config.get<Access::RandomAccess>()
            );
        } else if (type == "zipfian") {
            return std::make_unique<Access::ZipfianAccess>(
                config.get<Access::ZipfianAccess>()
            );
        } else {
            throw std::invalid_argument("get_access: type '" + type + "' not recognized");
        }
    }

    std::unique_ptr<Generator::Generator> get_generator(const json& config) {
        std::string type = config.at("type").get<std::string>();

        if (type == "constant") {
            return std::make_unique<Generator::ConstantGenerator>();
        } else if (type == "random") {
            return std::make_unique<Generator::RandomGenerator>();
        } else if (type == "dedup") {
            return std::make_unique<Generator::DeduplicationGenerator>(
                config.get<Generator::DeduplicationGeneratorConfig>()
            );
        } else {
            throw std::invalid_argument("get_generator: type '" + type + "' not recognized");
        }
    }

    std::unique_ptr<Operation::Operation> get_operation(const json& config) {
        std::string type = config.at("type").get<std::string>();

        if (type == "constant") {
            return std::make_unique<Operation::ConstantOperation>(
                config.get<Operation::ConstantOperation>()
            );
        } else if (type == "percentage") {
            return std::make_unique<Operation::PercentageOperation>(
                config.get<Operation::PercentageOperation>()
            );
        } else if (type == "sequence") {
            return std::make_unique<Operation::SequenceOperation>(
                config.get<Operation::SequenceOperation>()
            );
        } else {
            throw std::invalid_argument("get_operation: type '" + type + "' not recognized");
        }
    }

    std::unique_ptr<Operation::MultipleBarrier> get_multiple_barrier(const json& config) {
        return std::make_unique<Operation::MultipleBarrier>(
            config.get<Operation::MultipleBarrier>()
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