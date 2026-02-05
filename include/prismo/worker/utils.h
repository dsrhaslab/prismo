#ifndef WORKER_UTILS_H
#define WORKER_UTILS_H

#include <iostream>
#include <prismo/io/protocol.h>
#include <lib/concurrentqueue/concurrentqueue.h>

#define BULK_SIZE 64
#define QUEUE_INITIAL_CAPACITY 1024

namespace Worker {

    inline void init_queue_packet(
        moodycamel::ConcurrentQueue<Protocol::Packet*>& queue,
        size_t block_size
    ) {
        for (int index = 0; index < QUEUE_INITIAL_CAPACITY; index++) {
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
    }

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
    }
};

#endif