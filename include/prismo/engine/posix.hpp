#ifndef PRISMO_ENGINE_POSIX_H
#define PRISMO_ENGINE_POSIX_H

#include <cerrno>
#include <cstring>
#include <prismo/engine/engine.hpp>

namespace Engine {

    class PosixEngine : public Base {
        private:
            int nop(void);
            int fsync(Protocol::IORequest& request);
            int fdatasync(Protocol::IORequest& request);

            ssize_t read(Protocol::IORequest& request);
            ssize_t write(Protocol::IORequest& request);

        public:
            explicit PosixEngine(
                std::unique_ptr<Logger::Base> _logger
            );

            ~PosixEngine() override;

            int open(Protocol::OpenRequest& request) override;
            int close(Protocol::CloseRequest& request) override;
            void submit(Protocol::IORequest& request) override;
            void reap_left_completions(void) override {};
    };
}

#endif