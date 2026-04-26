#ifndef PRISMO_WORKER_PRODUCER_H
#define PRISMO_WORKER_PRODUCER_H

#include <spdlog/spdlog.h>
#include <prismo/control/ramp.hpp>
#include <prismo/control/termination.hpp>
#include <prismo/communication/channel.hpp>
#include <prismo/generator/access/generator.hpp>
#include <prismo/generator/content/generator.hpp>
#include <prismo/generator/content/compression.hpp>
#include <prismo/generator/operation/barrier.hpp>
#include <prismo/generator/operation/generator.hpp>

namespace Worker {

    class Producer {
        private:
            std::unique_ptr<Generator::AccessGenerator> access;
            std::unique_ptr<Generator::OperationGenerator> operation;
            std::unique_ptr<Generator::ContentGenerator> content;

            std::optional<Generator::MultipleBarrier> barrier;
            std::optional<Generator::CompressionGenerator> compression;

            std::optional<Control::Ramp> ramp;
            std::unique_ptr<Control::Termination> termination;

            std::shared_ptr<Communication::Channel> to_producer;
            std::shared_ptr<Communication::Channel> to_consumer;

        public:
            Producer(
                std::unique_ptr<Generator::AccessGenerator> _access,
                std::unique_ptr<Generator::OperationGenerator> _operation,
                std::unique_ptr<Generator::ContentGenerator> _content,
                std::optional<Generator::MultipleBarrier> _barrier,
                std::optional<Generator::CompressionGenerator> _compression,
                std::optional<Control::Ramp> _ramp,
                std::unique_ptr<Control::Termination> _termination,
                std::shared_ptr<Communication::Channel> _to_producer,
                std::shared_ptr<Communication::Channel> _to_consumer
            );

            void run(int fd, size_t job_id);
    };
};

#endif
