#include <prismo/engine/aio.hpp>

namespace Engine {

    AioEngine::AioEngine(
        Metric::MetricVariant _metric,
        std::shared_ptr<Logger::Base> _logger,
        const AioConfig& _config
    ) : Base(_metric, _logger) {
        int ret = io_queue_init(_config.entries, &io_context);
        if (ret < 0)
            throw std::runtime_error("aio_queue_init: failed: " + std::string(strerror(-ret)));

        iocbs.resize(_config.entries);
        tasks.resize(_config.entries);
        io_events.resize(_config.entries);
        iocb_ptrs.reserve(_config.entries);
        available_indexes.resize(_config.entries);

        for (uint32_t i = 0; i < _config.entries; i++) {
            available_indexes[i] = _config.entries - i - 1;
            tasks[i].buffer = std::malloc(_config.block_size);
            if (!tasks[i].buffer)
                throw std::bad_alloc();
        }
    }

    AioEngine::~AioEngine() {
        std::cout << "~Destroying AioEngine" << std::endl;
        for (auto& task : tasks) std::free(task.buffer);

        if (io_queue_release(io_context)) {
            std::cerr << "Aio destroy failed: " << strerror(errno) << std::endl;
        }
    }

    int AioEngine::open(Protocol::OpenRequest& request) {
        int fd = ::open(request.filename.c_str(), request.flags, request.mode);
        if (fd < 0)
            throw std::runtime_error("aio_open: failed to open file: " + std::string(strerror(errno)));
        return fd;
    }

    int AioEngine::close(Protocol::CloseRequest& request) {
        int ret = ::close(request.fd);
        if (ret < 0)
            throw std::runtime_error("aio_open: failed to close fd: " + std::string(strerror(errno)));
        return ret;
    }

    void AioEngine::nop(Protocol::IORequest& request, uint32_t free_index) {
        io_prep_pwrite(&iocbs[free_index], request.fd, nullptr, 0, 0);
    }

    void AioEngine::fsync(Protocol::IORequest& request, uint32_t free_index) {
        io_prep_fsync(&iocbs[free_index], request.fd);
    }

    void AioEngine::fdatasync(Protocol::IORequest& request, uint32_t free_index) {
        io_prep_fdsync(&iocbs[free_index], request.fd);
    }

    void AioEngine::read(Protocol::IORequest& request, uint32_t free_index) {
        io_prep_pread(&iocbs[free_index], request.fd, tasks[free_index].buffer, request.size, request.offset);
    }

    void AioEngine::write(Protocol::IORequest& request, uint32_t free_index) {
        std::memcpy(tasks[free_index].buffer, request.buffer, request.size);
        io_prep_pwrite(&iocbs[free_index], request.fd, tasks[free_index].buffer, request.size, request.offset);
    }

    void AioEngine::submit(Protocol::IORequest& request) {
        if (iocb_ptrs.size() == iocb_ptrs.capacity()) {
            int submit_result = io_submit(io_context, iocb_ptrs.size(), &iocb_ptrs[0]);
            if (submit_result != static_cast<int>(iocb_ptrs.size()))
                throw std::runtime_error("aio_submit: submission failed");
            iocb_ptrs.clear();
        }

        while (available_indexes.empty())
            this->reap_completions();

        uint32_t free_index = available_indexes.back();
        available_indexes.pop_back();

        AioTask& aio_task = tasks[free_index];
        aio_task.index = free_index;
        aio_task.metric_data.size = request.size;
        aio_task.metric_data.offset = request.offset;
        aio_task.metric_data.metadata = request.metadata;
        aio_task.metric_data.operation_type = request.operation;
        aio_task.metric_data.start_ns = Metric::get_current_timestamp();

        switch (request.operation) {
            case Operation::OperationType::READ:
                this->read(request, free_index);
                break;
            case Operation::OperationType::WRITE:
                this->write(request, free_index);
                break;
            case Operation::OperationType::FSYNC:
                this->fsync(request, free_index);
                break;
            case Operation::OperationType::FDATASYNC:
                this->fdatasync(request, free_index);
                break;
            case Operation::OperationType::NOP:
                this->nop(request, free_index);
                break;
        }

        iocbs[free_index].data = &aio_task;
        iocb_ptrs.push_back(&iocbs[free_index]);
    }

    void AioEngine::reap_completions(void) {
        int events_returned = io_getevents(io_context, 1, io_events.capacity(), io_events.data(), nullptr);
        if (events_returned < 0)
            throw std::runtime_error("aio_reap_completions getevents failed: " + std::string(strerror(-events_returned)));

        for (int i = 0; i < events_returned; i++) {
            io_event& ev = io_events[i];
            AioTask* completed_task = static_cast<AioTask*>(ev.data);

            Metric::fill_metric(
                metric,
                process_id,
                thread_id,
                completed_task->metric_data.operation_type,
                completed_task->metric_data.metadata.block_id,
                completed_task->metric_data.metadata.compression,
                completed_task->metric_data.offset,
                completed_task->metric_data.size,
                completed_task->metric_data.start_ns,
                ev.res
            );

            Base::log_metric(metric);
            Base::record_metric(metric);

            available_indexes.push_back(completed_task->index);
        }
    }

    void AioEngine::reap_left_completions(void) {
        int submit_result = io_submit(io_context, iocb_ptrs.size(), &iocb_ptrs[0]);
        if (submit_result != static_cast<int>(iocb_ptrs.size()))
            throw std::runtime_error("aio_reap_left_completions: submission failed");
        iocb_ptrs.clear();
        while (available_indexes.size() < available_indexes.capacity())
            this->reap_completions();
    }
}
