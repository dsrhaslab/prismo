#include <prismo/worker/consumer.hpp>

namespace Worker {

    Consumer::Consumer(
        std::unique_ptr<Engine::Base> _engine,
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> _to_producer,
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> _to_consumer
    ) :
        engine(std::move(_engine)),
        to_producer(_to_producer),
        to_consumer(_to_consumer) {}

    int Consumer::open(Protocol::OpenRequest& request) {
        return engine->open(request);
    }

    void Consumer::close(Protocol::CloseRequest& request) {
        engine->close(request);
    }

    const nlohmann::json& Consumer::get_report(void) const {
        return report;
    }

    void Consumer::run(void) {
        bool shudown = false;
        Protocol::Packet* packet;
        Protocol::Packet* packets[BULK_SIZE];

        engine->set_thread_id_current();
        engine->set_process_id_current();
        engine->start_statistics();

        while (!shudown) {
            size_t count = to_consumer->try_dequeue_bulk(packets, BULK_SIZE);

            for (size_t index = 0; index < count; index++) {
                packet = packets[index];

                if (packet->isShutDown) {
                    shudown = true;
                    break;
                }

                engine->submit(packet->request);
            }

            to_producer->enqueue_bulk(packets, count);
        }

        engine->reap_left_completions();
        engine->finish_statistics();
        report = engine->get_statistics_report();
    }
}
