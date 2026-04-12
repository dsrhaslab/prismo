#ifndef PRISMO_CHANNEL_CHANNEL_H
#define PRISMO_CHANNEL_CHANNEL_H

#include <memory>
#include <prismo/protocol/protocol.hpp>
#include <lib/concurrentqueue/concurrentqueue.h>
#include <lib/concurrentqueue/blockingconcurrentqueue.h>

namespace Communication {

    inline constexpr size_t BULK_SIZE = 64;
    inline constexpr size_t QUEUE_INITIAL_CAPACITY = 1024;

    class Channel {
        public:
            virtual ~Channel() = default;
            virtual void enqueue(std::unique_ptr<Protocol::Packet>&& item) = 0;
            virtual void enqueue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t count) = 0;
            virtual void dequeue(std::unique_ptr<Protocol::Packet>& item) = 0;
            virtual size_t dequeue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t max) = 0;

            void init(size_t block_size);
            void destroy(void);
    };

    class NonBlockingChannel : public Channel {
        private:
            moodycamel::ConcurrentQueue<std::unique_ptr<Protocol::Packet>> queue;
        public:
            NonBlockingChannel() = delete;
            explicit NonBlockingChannel(size_t capacity);

            void enqueue(std::unique_ptr<Protocol::Packet>&& item) override;
            void enqueue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t count) override;
            void dequeue(std::unique_ptr<Protocol::Packet>& item) override;
            size_t dequeue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t max) override;
    };

    class BlockingChannel : public Channel {
        private:
            moodycamel::BlockingConcurrentQueue<std::unique_ptr<Protocol::Packet>> queue;
        public:
            BlockingChannel() = delete;
            explicit BlockingChannel(size_t capacity);

            void enqueue(std::unique_ptr<Protocol::Packet>&& item) override;
            void enqueue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t count) override;
            void dequeue(std::unique_ptr<Protocol::Packet>& item) override;
            size_t dequeue_bulk(std::unique_ptr<Protocol::Packet>* items, size_t max) override;
    };
};

#endif
