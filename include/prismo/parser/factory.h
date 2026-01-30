#ifndef PARSER_FACTORY_H
#define PARSER_FACTORY_H

#include <memory>
#include <prismo/io/metric.h>
#include <prismo/generator/access/generator.h>
#include <prismo/generator/content/generator.h>
#include <prismo/generator/content/deduplication.h>
#include <prismo/generator/operation/generator.h>
#include <prismo/generator/operation/barrier.h>
#include <prismo/generator/realistic/repeat.h>
#include <prismo/logger/logger.h>
#include <prismo/logger/spdlog.h>
#include <prismo/engine/engine.h>
#include <prismo/engine/posix.h>
#include <prismo/engine/uring.h>
#include <prismo/engine/aio.h>
#include <prismo/engine/spdk.h>

namespace Parser {

    std::unique_ptr<Generator::AccessGenerator> get_access_generator(const json& config);
    std::unique_ptr<Generator::ContentGenerator> get_content_generator(const json& config);
    std::unique_ptr<Generator::OperationGenerator> get_operation_generator(const json& config);

    std::optional<Generator::MultipleBarrier> get_multiple_barrier(const json& config);

    std::unique_ptr<Metric::Metric> get_metric(const json& config);
    std::unique_ptr<Logger::Logger> get_logger(const json& config);
    std::unique_ptr<Engine::Engine> get_engine(
        const json& config,
        std::unique_ptr<Metric::Metric> metric,
        std::unique_ptr<Logger::Logger> logger
    );
};

#endif