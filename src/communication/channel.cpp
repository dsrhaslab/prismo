#include <prismo/communication/channel.hpp>

namespace Communication {

    void Channel::init(size_t block_size) {
        for (size_t i = 0; i < QUEUE_INITIAL_CAPACITY; i++) {
            auto packet = std::make_unique<Protocol::Packet>();
            packet->isShutDown = false;
            packet->request.fd = 0;
            packet->request.offset = 0;
            packet->request.metadata = {};
            packet->request.size = block_size;
            packet->request.operation = Operation::OperationType::NOP;
            packet->request.buffer = static_cast<uint8_t*>(
                std::aligned_alloc(block_size, block_size));

            if (!packet->request.buffer) {
                throw std::bad_alloc();
            }

            enqueue(std::move(packet));
        }
    }

    void Channel::destroy(void) {
        std::unique_ptr<Protocol::Packet> packet;
        for (size_t i = 0; i < QUEUE_INITIAL_CAPACITY; i++) {
            dequeue(packet);
            std::free(packet->request.buffer);
        }
    }

    NonBlockingChannel::NonBlockingChannel(size_t capacity) : queue(capacity) {}

    void NonBlockingChannel::enqueue(std::unique_ptr<Protocol::Packet>&& item) {
        while (!queue.enqueue(std::move(item)));
    }

    void NonBlockingChannel::enqueue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t count) {
        while (!queue.enqueue_bulk(std::make_move_iterator(items), count));
    }

    void NonBlockingChannel::dequeue(std::unique_ptr<Protocol::Packet>& item) {
        while (!queue.try_dequeue(item));
    }

    size_t NonBlockingChannel::dequeue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t max) {
        size_t count = 0;
        while (count == 0) {
            count = queue.try_dequeue_bulk(items, max);
        }
        return count;
    }

    BlockingChannel::BlockingChannel(size_t capacity) : queue(capacity) {}

    void BlockingChannel::enqueue(std::unique_ptr<Protocol::Packet>&& item) {
        while (!queue.enqueue(std::move(item)));
    }

    void BlockingChannel::enqueue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t count) {
        while (!queue.enqueue_bulk(std::make_move_iterator(items), count));
    }

    void BlockingChannel::dequeue(std::unique_ptr<Protocol::Packet>& item) {
        queue.wait_dequeue(item);
    }

    size_t BlockingChannel::dequeue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t max) {
        return queue.wait_dequeue_bulk(items, max);
    }
};
