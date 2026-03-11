#include <prismo/worker/consumer.hpp>

namespace Worker {

    Consumer::Consumer(
        std::unique_ptr<Engine::Base> _engine,
        std::shared_ptr<moodycamel::ConcurrentQueue<std::unique_ptr<Protocol::Packet>>> _to_producer,
        std::shared_ptr<moodycamel::ConcurrentQueue<std::unique_ptr<Protocol::Packet>>> _to_consumer
    )
        : engine(std::move(_engine))
        , to_producer(std::move(_to_producer))
        , to_consumer(std::move(_to_consumer))
    {}

    int Consumer::open(Protocol::OpenRequest& request) const {
        return engine->open(request);
    }

    void Consumer::close(Protocol::CloseRequest& request) const {
        engine->close(request);
    }

    const Metric::Statistics Consumer::get_statistics(void) const {
        return engine->get_statistics();
    }

    void Consumer::run(void) const {
        bool shudown = false;
        std::unique_ptr<Protocol::Packet> packets[Internal::BULK_SIZE];

        engine->set_thread_id_current();
        engine->set_process_id_current();
        engine->start_statistics();

        while (!shudown) {
            size_t count = to_consumer->try_dequeue_bulk(packets, Internal::BULK_SIZE);

            for (size_t index = 0; index < count; index++) {
                if (packets[index]->isShutDown) {
                    shudown = true;
                    break;
                }

                engine->submit(packets[index]->request);
            }

            to_producer->enqueue_bulk(std::make_move_iterator(packets), count);
        }

        engine->reap_left_completions();
        engine->finish_statistics();
    }
}
