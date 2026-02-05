#ifndef PRODUCER_WORKER_H
#define PRODUCER_WORKER_H

#include <prismo/generator/access/generator.h>
#include <prismo/generator/content/compression.h>
#include <prismo/generator/content/generator.h>
#include <prismo/generator/operation/barrier.h>
#include <prismo/generator/operation/generator.h>
#include <prismo/worker/utils.h>

namespace Worker {

    class Producer {
       private:
        std::unique_ptr<Generator::AccessGenerator> access;
        std::unique_ptr<Generator::OperationGenerator> operation;
        std::unique_ptr<Generator::ContentGenerator> content;
        std::optional<Generator::CompressionGenerator> compression;
        std::optional<Generator::MultipleBarrier> barrier;
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>>
            to_producer;
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>>
            to_consumer;

       public:
        Producer(std::unique_ptr<Generator::AccessGenerator> _access,
                 std::unique_ptr<Generator::OperationGenerator> _operation,
                 std::unique_ptr<Generator::ContentGenerator> _content,
                 std::optional<Generator::CompressionGenerator> _compression,
                 std::optional<Generator::MultipleBarrier> _barrier,
                 std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>>
                     _to_producer,
                 std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>>
                     _to_consumer)
            : access(std::move(_access)),
              operation(std::move(_operation)),
              content(std::move(_content)),
              compression(std::move(_compression)),
              barrier(std::move(_barrier)),
              to_producer(_to_producer),
              to_consumer(_to_consumer) {}

        void run(uint64_t iterations, int fd) {
            Protocol::Packet* packet;
            Protocol::Packet* packets[BULK_SIZE];

            while (iterations > 0) {
                size_t ready = 0;
                size_t count =
                    to_producer->try_dequeue_bulk(packets, BULK_SIZE);

                for (ready = 0; ready < count && iterations != 0;
                     ready++, iterations--) {
                    packet = packets[ready];
                    packet->request.fd = fd;
                    packet->request.offset = access->next_offset();
                    packet->request.operation = operation->next_operation();

                    if (barrier.has_value()) {
                        packet->request.operation =
                            barrier->apply(packet->request.operation);
                    }

                    packet->request.metadata.block_id = 0;
                    packet->request.metadata.compression = 0;

                    if (packet->request.operation ==
                        Operation::OperationType::WRITE) {
                        packet->request.metadata = content->next_block(
                            packet->request.buffer, packet->request.size);

                        if (compression.has_value()) {
                            packet->request.metadata.compression =
                                compression->apply(packet->request.buffer,
                                                   packet->request.size);
                        }
                    }
                }

                to_consumer->enqueue_bulk(packets, ready);
                to_producer->enqueue_bulk(
                    packets + ready,
                    count - ready);  // enqueue unused packets
            }

            while (!to_producer->try_dequeue(packet))
                ;
            packet->isShutDown = true;
            to_consumer->enqueue(packet);
        }
    };
};  // namespace Worker

#endif