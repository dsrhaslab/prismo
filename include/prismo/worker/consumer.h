#ifndef CONSUMER_WORKER_H
#define CONSUMER_WORKER_H

#include <lib/concurrentqueue/concurrentqueue.h>
#include <prismo/engine/engine.h>
#include <prismo/worker/utils.h>
#include <memory>

namespace Worker {

    class Consumer {
       private:
        std::unique_ptr<Engine::Engine> engine;
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>>
            to_producer;
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>>
            to_consumer;

       public:
        Consumer(std::unique_ptr<Engine::Engine> _engine,
                 std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>>
                     _to_producer,
                 std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>>
                     _to_consumer)
            : engine(std::move(_engine)),
              to_producer(_to_producer),
              to_consumer(_to_consumer) {}

        int open(Protocol::OpenRequest& request) {
            return engine->open(request);
        }

        void close(Protocol::CloseRequest& request) { engine->close(request); }

        void run(void) {
            bool shudown = false;
            Protocol::Packet* packet;
            Protocol::Packet* packets[BULK_SIZE];

            while (!shudown) {
                size_t count =
                    to_consumer->try_dequeue_bulk(packets, BULK_SIZE);

                for (size_t index = 0; index < count; index++) {
                    packet = packets[index];

                    if (packet->isShutDown) {
                        shudown = true;
                        break;
                    }  // nothing after shutdown (FIFO)

                    engine->submit(packet->request);
                }

                to_producer->enqueue_bulk(packets, count);
            }

            engine->reap_left_completions();
        }
    };
};  // namespace Worker

#endif
