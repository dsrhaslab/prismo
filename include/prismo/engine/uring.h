#ifndef URING_ENGINE_H
#define URING_ENGINE_H

#include <prismo/engine/engine.h>

namespace Engine {

    class UringEngine : public Engine {
       private:
        io_uring ring;
        std::vector<iovec> iovecs;
        std::vector<UringUserData> user_data;
        std::vector<uint32_t> available_indexes;
        std::vector<io_uring_cqe*> completed_cqes;

        void nop(io_uring_sqe* sqe);
        void fsync(Protocol::IORequest& request, io_uring_sqe* sqe);
        void fdatasync(Protocol::IORequest& request, io_uring_sqe* sqe);

        void read(Protocol::IORequest& request, io_uring_sqe* sqe,
                  uint32_t free_index);
        void write(Protocol::IORequest& request, io_uring_sqe* sqe,
                   uint32_t free_index);

        void reap_completions(void);

       public:
        explicit UringEngine(std::unique_ptr<Metric::Metric> _metric,
                             std::unique_ptr<Logger::Logger> _logger,
                             const UringConfig& _config);

        ~UringEngine() override;

        int open(Protocol::OpenRequest& request) override;
        int close(Protocol::CloseRequest& request) override;
        void submit(Protocol::IORequest& request) override;
        void reap_left_completions(void) override;
    };
};  // namespace Engine

#endif