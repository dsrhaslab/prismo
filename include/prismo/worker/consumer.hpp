#ifndef PRISMO_WORKER_CONSUMER_H
#define PRISMO_WORKER_CONSUMER_H

#include <prismo/engine/engine.hpp>
#include <prismo/worker/packet_pool.hpp>
#include <lib/concurrentqueue/concurrentqueue.h>

namespace Worker {

    class Consumer {
        private:
            nlohmann::json report;
            std::unique_ptr<Engine::Base> engine;
            std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> to_producer;
            std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> to_consumer;

        public:
            Consumer(
                std::unique_ptr<Engine::Base> _engine,
                std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> _to_producer,
                std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> _to_consumer
            );

            int open(Protocol::OpenRequest& request);

            void close(Protocol::CloseRequest& request);

            const nlohmann::json& get_report(void) const;

            void run(void);
    };
};

#endif
