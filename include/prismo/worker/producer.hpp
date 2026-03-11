#ifndef PRISMO_WORKER_PRODUCER_H
#define PRISMO_WORKER_PRODUCER_H

#include <prismo/worker/ramp.hpp>
#include <prismo/worker/termination.hpp>
#include <prismo/worker/packet_pool.hpp>
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

            std::optional<Internal::Ramp> ramp;
            std::unique_ptr<Internal::Termination> termination;

            std::shared_ptr<moodycamel::ConcurrentQueue<std::unique_ptr<Protocol::Packet>>> to_producer;
            std::shared_ptr<moodycamel::ConcurrentQueue<std::unique_ptr<Protocol::Packet>>> to_consumer;

        public:
            Producer(
                std::unique_ptr<Generator::AccessGenerator> _access,
                std::unique_ptr<Generator::OperationGenerator> _operation,
                std::unique_ptr<Generator::ContentGenerator> _content,
                std::optional<Generator::MultipleBarrier> _barrier,
                std::optional<Generator::CompressionGenerator> _compression,
                std::optional<Internal::Ramp> _ramp,
                std::unique_ptr<Internal::Termination> _termination,
                std::shared_ptr<moodycamel::ConcurrentQueue<std::unique_ptr<Protocol::Packet>>> _to_producer,
                std::shared_ptr<moodycamel::ConcurrentQueue<std::unique_ptr<Protocol::Packet>>> _to_consumer
            );

            void run(int fd);
    };
};

#endif