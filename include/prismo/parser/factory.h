#ifndef PARSER_FACTORY_H
#define PARSER_FACTORY_H

#include <prismo/engine/aio.h>
#include <prismo/engine/engine.h>
#include <prismo/engine/posix.h>
#include <prismo/engine/spdk.h>
#include <prismo/engine/uring.h>
#include <prismo/generator/access/generator.h>
#include <prismo/generator/content/compression.h>
#include <prismo/generator/content/deduplication.h>
#include <prismo/generator/content/generator.h>
#include <prismo/generator/operation/barrier.h>
#include <prismo/generator/operation/generator.h>
#include <prismo/generator/tracebased/extension.h>
#include <prismo/generator/tracebased/tracebased.h>
#include <prismo/io/metric.h>
#include <prismo/logger/logger.h>
#include <prismo/logger/spdlog.h>
#include <prismo/worker/ramp.h>

namespace Parser {

    std::unique_ptr<Extension::TraceExtension> get_trace_extension(
        const nlohmann::json& config);

    std::unique_ptr<Generator::AccessGenerator> get_access_generator(
        const nlohmann::json& config);

    std::unique_ptr<Generator::OperationGenerator> get_operation_generator(
        const nlohmann::json& config);

    std::unique_ptr<Generator::ContentGenerator> get_content_generator(
        const nlohmann::json& config);

    std::optional<Generator::MultipleBarrier> get_multiple_barrier(
        const nlohmann::json& config);

    std::optional<Generator::CompressionGenerator> get_compression_generator(
        const nlohmann::json& config);

    std::optional<Worker::Ramp> get_ramp(
        const nlohmann::json& config);

    Metric::MetricVariant get_metric(const nlohmann::json& config);

    std::shared_ptr<Logger::Logger> get_logger(const nlohmann::json& config);

    std::unique_ptr<Engine::Engine> get_engine(
        const nlohmann::json& config,
        Metric::MetricVariant metric,
        std::shared_ptr<Logger::Logger> logger);
};

#endif