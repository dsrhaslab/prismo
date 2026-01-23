#ifndef PARSER_H
#define PARSER_H

#include <memory>
#include <io/metric.h>
#include <access/synthetic.h>
#include <generator/synthetic.h>
#include <generator/deduplication.h>
#include <operation/synthetic.h>
#include <operation/barrier.h>
#include <logger/logger.h>
#include <logger/spdlog.h>
#include <engine/engine.h>
#include <engine/posix.h>
#include <engine/uring.h>
#include <engine/aio.h>
#include <engine/spdk.h>

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