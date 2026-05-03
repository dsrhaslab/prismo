#include <prismo/engine/posix.hpp>

namespace Engine {

    PosixEngine::PosixEngine(
        std::unique_ptr<Logger::Base> _logger
    ) : Base(std::move(_logger)) {}

    PosixEngine::~PosixEngine() {
        std::cout << "~Destroying PosixEngine" << std::endl;
    }

    int PosixEngine::open(Protocol::OpenRequest& request) {
        int fd = ::open(request.filename.c_str(), request.flags, request.mode);
        if (fd < 0)
            throw std::runtime_error("posix_open: failed to open file: " + std::string(strerror(errno)));
        return fd;
    }

    int PosixEngine::close(Protocol::CloseRequest& request) {
        int rt = ::close(request.fd);
        if (rt < 0)
            throw std::runtime_error("posix_close: failed to close fd: " + std::string(strerror(errno)));
        return rt;
    }

    int PosixEngine::nop(void) {
        return 0;
    }

    int PosixEngine::fsync(Protocol::IORequest& request) {
        return ::fsync(request.fd);
    }

    int PosixEngine::fdatasync(Protocol::IORequest& request) {
        return ::fdatasync(request.fd);
    }

    ssize_t PosixEngine::read(Protocol::IORequest& request) {
        return ::pread(request.fd, request.buffer, request.size, request.offset);
    }

    ssize_t PosixEngine::write(Protocol::IORequest& request) {
        return ::pwrite(request.fd, request.buffer, request.size, request.offset);
    }

    void PosixEngine::submit(Protocol::IORequest& request) {
        ssize_t result = 0;
        uint64_t start_ns = Metric::get_current_timestamp();

        switch (request.operation) {
            case Operation::OperationType::READ:
                result = this->read(request);
                break;
            case Operation::OperationType::WRITE:
                result = this->write(request);
                break;
            case Operation::OperationType::FSYNC:
                result = this->fsync(request);
                break;
            case Operation::OperationType::FDATASYNC:
                result = this->fdatasync(request);
                break;
            case Operation::OperationType::NOP:
                result = this->nop();
                break;
        }

        Metric::Metric m = Metric::create_metric(
            request.operation,
            request.metadata.block_id,
            request.metadata.compression,
            start_ns,
            process_id,
            thread_id,
            request.size,
            request.offset,
            result
        );

        Base::log_metric(m);
        Base::record_metric(m);
    }
}
