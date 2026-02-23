#ifndef POSIX_ENGINE_H
#define POSIX_ENGINE_H

#include <prismo/engine/engine.h>

namespace Engine {

    class PosixEngine : public Engine {
        private:
            int nop(void);
            int fsync(Protocol::IORequest& request);
            int fdatasync(Protocol::IORequest& request);

            ssize_t read(Protocol::IORequest& request);
            ssize_t write(Protocol::IORequest& request);

        public:
            explicit PosixEngine(
                Metric::MetricVariant _metric,
                std::shared_ptr<Logger::Logger> _logger = nullptr
            );

            ~PosixEngine() override;

            int open(Protocol::OpenRequest& request) override;
            int close(Protocol::CloseRequest& request) override;
            void submit(Protocol::IORequest& request) override;
            void reap_left_completions(void) override {};
    };
}

#endif