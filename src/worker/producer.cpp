#include <prismo/worker/producer.hpp>

namespace Worker {

    Producer::Producer(
        std::unique_ptr<Generator::AccessGenerator> _access,
        std::unique_ptr<Generator::OperationGenerator> _operation,
        std::unique_ptr<Generator::ContentGenerator> _content,
        std::optional<Generator::MultipleBarrier> _barrier,
        std::optional<Generator::CompressionGenerator> _compression,
        std::optional<Internal::Ramp> _ramp,
        std::unique_ptr<Internal::Termination> _termination,
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> _to_producer,
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> _to_consumer
    )
        : access(std::move(_access))
        , operation(std::move(_operation))
        , content(std::move(_content))
        , barrier(std::move(_barrier))
        , compression(std::move(_compression))
        , ramp(std::move(_ramp))
        , termination(std::move(_termination))
        , to_producer(std::move(_to_producer))
        , to_consumer(std::move(_to_consumer))
    {}

    void Producer::run(int fd) {
        Protocol::Packet* packet;
        Protocol::Packet* packets[Internal::BULK_SIZE];

        uint64_t iterations_count = 0;
        auto start_time = std::chrono::steady_clock::now();

        while (termination->should_continue(start_time, iterations_count)) {
            auto batch_start = std::chrono::steady_clock::now();
            size_t ready = 0;
            size_t count = to_producer->try_dequeue_bulk(packets, Internal::BULK_SIZE);

            while (ready < count &&
                   termination->should_continue(start_time, iterations_count)) {
                packet = packets[ready];
                packet->request.fd = fd;
                packet->request.offset = access->next_offset();
                packet->request.operation = operation->next_operation();

                if (barrier.has_value()) {
                    packet->request.operation = barrier->apply(packet->request.operation);
                }

                packet->request.metadata.block_id = 0;
                packet->request.metadata.compression = 0;

                if (packet->request.operation == Operation::OperationType::WRITE) {
                    packet->request.metadata = content->next_block(
                        packet->request.buffer,
                        packet->request.size
                    );

                    if (compression.has_value()) {
                        uint32_t compression_value = compression->apply(
                            packet->request.buffer,
                            packet->request.size
                        );

                        packet->request.metadata.compression =
                            compression_value > packet->request.metadata.compression ?
                            compression_value : packet->request.metadata.compression;
                    }
                }

                ready++;
                iterations_count++;
            }

            to_consumer->enqueue_bulk(packets, ready);
            to_producer->enqueue_bulk(packets + ready, count - ready);

            if (ramp.has_value()) {
                ramp->throttle(start_time, batch_start);
            }
        }

        while (!to_producer->try_dequeue(packet));

        packet->isShutDown = true;
        to_consumer->enqueue(packet);
    }
}
