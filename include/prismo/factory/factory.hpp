#ifndef PRISMO_FACTORY_FACTORY_H
#define PRISMO_FACTORY_FACTORY_H

#include <prismo/engine/aio.hpp>
#include <prismo/engine/engine.hpp>
#include <prismo/engine/posix.hpp>
#include <prismo/engine/spdk.hpp>
#include <prismo/engine/uring.hpp>
#include <prismo/generator/access/generator.hpp>
#include <prismo/generator/content/compression.hpp>
#include <prismo/generator/content/generator.hpp>
#include <prismo/generator/content/deduplication.hpp>
#include <prismo/generator/operation/barrier.hpp>
#include <prismo/generator/operation/generator.hpp>
#include <prismo/generator/tracebased/tracebased.hpp>
#include <prismo/logger/logger.hpp>
#include <prismo/logger/spdlog.hpp>
#include <prismo/metric/metric.hpp>
#include <prismo/worker/ramp.hpp>

namespace Factory {

    std::unique_ptr<Generator::Extension::TraceExtension> get_trace_extension(
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

    Metric::MetricVariant get_metric(
        const nlohmann::json& config);

    std::shared_ptr<Logger::Base> get_logger(
        const nlohmann::json& config);

    std::unique_ptr<Engine::Base> get_engine(
        const nlohmann::json& config,
        Metric::MetricVariant metric,
        std::shared_ptr<Logger::Base> logger);
};

#endif