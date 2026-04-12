#ifndef PRISMO_WORKER_CONSUMER_H
#define PRISMO_WORKER_CONSUMER_H

#include <prismo/engine/engine.hpp>
#include <prismo/communication/channel.hpp>

namespace Worker {

    class Consumer {
        private:
            std::unique_ptr<Engine::Base> engine;
            std::shared_ptr<Communication::Channel> to_producer;
            std::shared_ptr<Communication::Channel> to_consumer;

        public:
            Consumer(
                std::unique_ptr<Engine::Base> _engine,
                std::shared_ptr<Communication::Channel> _to_producer,
                std::shared_ptr<Communication::Channel> _to_consumer
            );

            int open(Protocol::OpenRequest& request) const;

            void close(Protocol::CloseRequest& request) const;

            const Metric::Statistics get_statistics(void) const;

            void run(void) const;
    };
};

#endif
