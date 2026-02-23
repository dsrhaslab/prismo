#ifndef PRODUCER_WORKER_H
#define PRODUCER_WORKER_H

#include <prismo/worker/utils.h>
#include <prismo/worker/termination.h>
#include <prismo/generator/access/generator.h>
#include <prismo/generator/content/generator.h>
#include <prismo/generator/content/compression.h>
#include <prismo/generator/operation/barrier.h>
#include <prismo/generator/operation/generator.h>

namespace Worker {

    class Producer {
        private:
            std::unique_ptr<Generator::AccessGenerator> access;
            std::unique_ptr<Generator::OperationGenerator> operation;
            std::unique_ptr<Generator::ContentGenerator> content;
            std::optional<Generator::CompressionGenerator> compression;
            std::optional<Generator::MultipleBarrier> barrier;
            std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> to_producer;
            std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> to_consumer;

        public:
            Producer(
                std::unique_ptr<Generator::AccessGenerator> _access,
                std::unique_ptr<Generator::OperationGenerator> _operation,
                std::unique_ptr<Generator::ContentGenerator> _content,
                std::optional<Generator::CompressionGenerator> _compression,
                std::optional<Generator::MultipleBarrier> _barrier,
                std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> _to_producer,
                std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> _to_consumer
            ) :
                access(std::move(_access)),
                operation(std::move(_operation)),
                content(std::move(_content)),
                compression(std::move(_compression)),
                barrier(std::move(_barrier)),
                to_producer(_to_producer),
                to_consumer(_to_consumer) {}

            void run(
                int fd,
                const Termination& termination
            ) {
                Protocol::Packet* packet;
                Protocol::Packet* packets[BULK_SIZE];

                uint64_t iterations_count = 0;
                auto start_time = std::chrono::steady_clock::now();

                while (TerminationManager::should_continue(
                    termination, start_time, iterations_count)
                ) {
                    size_t ready = 0;
                    size_t count = to_producer->try_dequeue_bulk(packets, BULK_SIZE);

                    while (ready < count &&
                           TerminationManager::should_continue(
                               termination, start_time, iterations_count)
                    ) {
                        packet = packets[ready];
                        packet->request.fd = fd;
                        packet->request.offset = access->next_offset();
                        packet->request.operation = operation->next_operation();

                        if (barrier.has_value()) {
                            packet->request.operation = barrier->apply(packet->request.operation);
                        }

                        packet->request.metadata.block_id = 0;
                        packet->request.metadata.compression = 0;

                        if (packet->request.operation == Operation::OperationType::WRITE) {
                            packet->request.metadata = content->next_block(
                                packet->request.buffer,
                                packet->request.size
                            );

                            if (compression.has_value()) {
                                uint32_t compression_value = compression->apply(
                                    packet->request.buffer,
                                    packet->request.size
                                );

                                packet->request.metadata.compression =
                                    compression_value > packet->request.metadata.compression ?
                                    compression_value : packet->request.metadata.compression;
                            }
                        }

                        ready++;
                        iterations_count++;
                    }

                    to_consumer->enqueue_bulk(packets, ready);
                    to_producer->enqueue_bulk(packets + ready, count - ready); // enqueue unused packets
                }

                while (!to_producer->try_dequeue(packet));
                packet->isShutDown = true;
                to_consumer->enqueue(packet);
            }
    };
};

#endif