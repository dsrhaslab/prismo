#include <prismo/worker/producer.hpp>

namespace Worker {

    Producer::Producer(
        std::unique_ptr<Generator::AccessGenerator> _access,
        std::unique_ptr<Generator::OperationGenerator> _operation,
        std::unique_ptr<Generator::ContentGenerator> _content,
        std::optional<Generator::MultipleBarrier> _barrier,
        std::optional<Generator::CompressionGenerator> _compression,
        std::optional<Control::Ramp> _ramp,
        std::unique_ptr<Control::Termination> _termination,
        std::shared_ptr<Communication::Channel> _to_producer,
        std::shared_ptr<Communication::Channel> _to_consumer
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

    void Producer::run(int fd, size_t job_id) {
        std::unique_ptr<Protocol::Packet> shutdown_packet;
        std::unique_ptr<Protocol::Packet> packets[Communication::BULK_SIZE];

        termination->start();

        while (termination->should_continue()) {
            auto batch_start = std::chrono::steady_clock::now();
            size_t ready = 0;
            size_t count = to_producer->dequeue_bulk(packets, Communication::BULK_SIZE);

            while (ready < count && termination->should_continue()) {
                auto& packet = packets[ready];
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

                        packet->request.metadata.compression = std::max(
                            compression_value,
                            packet->request.metadata.compression
                        );
                    }
                }

                ready++;
                termination->next_iteration();

                if (termination->is_time_check_due()) {
                    spdlog::debug("Progress job {}: {}",
                        job_id, termination->progress());
                }
            }

            to_consumer->enqueue_bulk(packets, ready);
            to_producer->enqueue_bulk(packets + ready, count - ready);

            if (ramp.has_value()) {
                ramp->throttle(termination->get_start_time(), batch_start);
            }
        }

        spdlog::debug("Progress job {}: {}",
            job_id, termination->progress());

        to_producer->dequeue(shutdown_packet);

        shutdown_packet->isShutDown = true;
        to_consumer->enqueue(std::move(shutdown_packet));
    }
}
