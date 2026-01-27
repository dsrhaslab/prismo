#include <prismo/engine/uring.h>

namespace Engine {

    UringEngine::UringEngine(
        std::unique_ptr<Metric::Metric> _metric,
        std::unique_ptr<Logger::Logger> _logger,
        const UringConfig& _config
    ) :
        Engine(std::move(_metric), std::move(_logger)),
        ring(),
        iovecs(),
        user_data(),
        available_indexes(),
        completed_cqes()
    {
        UringConfig config = _config;
        int ret = io_uring_queue_init_params(config.entries, &ring, &config.params);
        if (ret)
            throw std::runtime_error("uring_constructor: initialization failed: " + std::string(strerror(ret)));

        iovecs.resize(config.params.sq_entries);
        user_data.resize(config.params.sq_entries);
        available_indexes.resize(config.params.sq_entries);
        completed_cqes.resize(config.params.cq_entries);

        for (uint32_t index = 0; index < config.params.sq_entries; index++) {
            available_indexes[index] = config.params.sq_entries - index - 1;
            iovecs[index].iov_len = config.block_size;
            iovecs[index].iov_base = std::malloc(config.block_size);
            if (!iovecs[index].iov_base)
                throw std::bad_alloc();
        }

        ret = io_uring_register_buffers(&ring, iovecs.data(), config.params.sq_entries);
        if (ret) {
            io_uring_queue_exit(&ring);
            throw std::runtime_error("uring_constructor: register buffers failed: " + std::string(strerror(errno)));
        }
    }

    UringEngine::~UringEngine() {
        std::cout << "~Destroying UringEngine" << std::endl;
        if (io_uring_unregister_buffers(&ring))
            std::cerr << "uring_destructor: unregister buffers failed: " << strerror(errno) << std::endl;
        for (auto& iv : iovecs)
            std::free(iv.iov_base);
        io_uring_queue_exit(&ring);
    }

    int UringEngine::open(Protocol::OpenRequest& request) {
        int fd = ::open(request.filename.c_str(), request.flags, request.mode);
        if (fd < 0)
            throw std::runtime_error("uring_open: failed to open file: " + std::string(strerror(errno)));
        int ret = io_uring_register_files(&ring, &fd, 1);
        if (ret)
            throw std::runtime_error("uring_open: register file failed: " + std::string(strerror(ret)));
        return fd;
    }

    int UringEngine::close(Protocol::CloseRequest& request) {
        if (io_uring_unregister_files(&ring))
            throw std::runtime_error("uring_close: unregister files failed: " + std::string(strerror(errno)));
        if (::close(request.fd) < 0)
            throw std::runtime_error("uring_close: failed to close fd: " + std::string(strerror(errno)));
        return 0;
    }

    void UringEngine::nop(io_uring_sqe* sqe) {
        io_uring_prep_nop(sqe);
    }

    void UringEngine::fsync(Protocol::CommonRequest& request, io_uring_sqe* sqe) {
        io_uring_prep_fsync(sqe, request.fd, 0);
    }

    void UringEngine::fdatasync(Protocol::CommonRequest& request, io_uring_sqe* sqe) {
        io_uring_prep_fsync(sqe, request.fd, IORING_FSYNC_DATASYNC);
    }

    void UringEngine::read(Protocol::CommonRequest& request, io_uring_sqe* sqe, uint32_t free_index) {
        io_uring_prep_read_fixed(sqe, request.fd, iovecs[free_index].iov_base, request.size, request.offset, free_index);
    }

    void UringEngine::write(Protocol::CommonRequest& request, io_uring_sqe* sqe, uint32_t free_index) {
        std::memcpy(iovecs[free_index].iov_base, request.buffer, request.size);
        io_uring_prep_write_fixed(sqe, request.fd, iovecs[free_index].iov_base, request.size, request.offset, free_index);
    }

    void UringEngine::submit(Protocol::CommonRequest& request) {
        uint32_t free_index;
        io_uring_sqe* sqe = io_uring_get_sqe(&ring);
        request.fd = 0;

        if (!sqe) {
            int submitted = io_uring_submit(&ring);
            // std::cout << "Submitted " << submitted << " entries to uring." << std::endl;
        }

        if (available_indexes.empty())
            this->reap_completions();

        while (!sqe)
            sqe = io_uring_get_sqe(&ring);

        free_index = available_indexes.back();
        available_indexes.pop_back();

        UringUserData& uring_user_data = user_data[free_index];
        uring_user_data.index = free_index;
        uring_user_data.metric_data.size = request.size;
        uring_user_data.metric_data.offset = request.offset;
        uring_user_data.metric_data.metadata = request.metadata;
        uring_user_data.metric_data.operation_type = request.operation;
        uring_user_data.metric_data.start_timestamp = Metric::get_current_timestamp();

        switch (request.operation) {
            case Operation::OperationType::READ:
                this->read(request, sqe, free_index);
                break;
            case Operation::OperationType::WRITE:
                this->write(request, sqe, free_index);
                break;
            case Operation::OperationType::FSYNC:
                this->fsync(request, sqe);
                break;
            case Operation::OperationType::FDATASYNC:
                this->fdatasync(request, sqe);
                break;
            case Operation::OperationType::NOP:
                this->nop(sqe);
                break;
        }

        io_uring_sqe_set_data(sqe, &uring_user_data);
        sqe->flags |= IOSQE_FIXED_FILE;
    }

    void UringEngine::reap_completions(void) {
        int completions;

        do {
            completions = io_uring_peek_batch_cqe(
                &ring, completed_cqes.data(), completed_cqes.capacity());
        } while (!completions);

        for (int i = 0; i < completions; i++) {
            io_uring_cqe* cqe = completed_cqes[i];
            UringUserData* uring_user_data = static_cast<UringUserData*>(io_uring_cqe_get_data(cqe));

            Metric::fill_metric(
                *Engine::metric,
                uring_user_data->metric_data.operation_type,
                uring_user_data->metric_data.metadata.block_id,
                uring_user_data->metric_data.metadata.compression,
                uring_user_data->metric_data.start_timestamp,
                Metric::get_current_timestamp(),
                cqe->res,
                uring_user_data->metric_data.size,
                uring_user_data->metric_data.offset
            );

            Engine::logger->info(*Engine::metric);
            available_indexes.push_back(uring_user_data->index);
            io_uring_cqe_seen(&ring, cqe);
        }
    }

    void UringEngine::reap_left_completions(void) {
        int submitted = io_uring_submit(&ring);
        // std::cout << "Final Submitted " << submitted << " entries to uring." << std::endl;
        while (available_indexes.size() < available_indexes.capacity()) {
            this->reap_completions();
        }
    }
}