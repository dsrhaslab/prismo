#ifndef PARSER_H
#define PARSER_H

#include <memory>
#include <prismo/io/metric.h>
#include <prismo/access/synthetic.h>
#include <prismo/generator/synthetic.h>
#include <prismo/generator/deduplication.h>
#include <prismo/operation/synthetic.h>
#include <prismo/operation/barrier.h>
#include <prismo/logger/logger.h>
#include <prismo/logger/spdlog.h>
#include <prismo/engine/engine.h>
#include <prismo/engine/posix.h>
#include <prismo/engine/uring.h>
#include <prismo/engine/aio.h>
#include <prismo/engine/spdk.h>

namespace Parser {

    std::unique_ptr<Access::Access> get_access(const json& config);
    std::unique_ptr<Generator::Generator> get_generator(const json& config);
    std::unique_ptr<Operation::Operation> get_operation(const json& config);
    std::unique_ptr<Operation::MultipleBarrier> get_multiple_barrier(const json& config);

    std::unique_ptr<Metric::Metric> get_metric(const json& config);
    std::unique_ptr<Logger::Logger> get_logger(const json& config);
    std::unique_ptr<Engine::Engine> get_engine(
        const json& config,
        std::unique_ptr<Metric::Metric> metric,
        std::unique_ptr<Logger::Logger> logger
    );
};

#endif