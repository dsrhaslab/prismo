#ifndef PRISMO_WORKER_PACKET_POOL_H
#define PRISMO_WORKER_PACKET_POOL_H

#include <prismo/protocol/protocol.hpp>
#include <lib/concurrentqueue/concurrentqueue.h>

namespace Worker::Internal {

    inline constexpr size_t BULK_SIZE = 64;
    inline constexpr size_t QUEUE_INITIAL_CAPACITY = 1024;

    inline void init_queue_packet(
        moodycamel::ConcurrentQueue<Protocol::Packet*>& queue,
        size_t block_size
    ) {
        for (size_t i = 0; i < QUEUE_INITIAL_CAPACITY; i++) {
            Protocol::Packet* packet = new Protocol::Packet();
            packet->isShutDown = false;
            packet->request.fd = 0;
            packet->request.offset = 0;
            packet->request.metadata = {};
            packet->request.size = block_size;
            packet->request.operation = Operation::OperationType::NOP;
            packet->request.buffer = static_cast<uint8_t*>(std::malloc(block_size));

            if (!packet->request.buffer) {
                throw std::bad_alloc();
            }

            queue.enqueue(packet);
        }
    };

    inline void destroy_queue_packet(
        moodycamel::ConcurrentQueue<Protocol::Packet*>& queue,
        size_t queue_size
    ) {
        Protocol::Packet* packet;
        for (size_t index = 0; index < queue_size; index++) {
            while (!queue.try_dequeue(packet));
            std::free(packet->request.buffer);
            delete packet;
        }
    };
};

#endif