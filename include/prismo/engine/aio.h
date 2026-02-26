#ifndef PRISMO_ENGINE_AIO_H
#define PRISMO_ENGINE_AIO_H

#include <prismo/engine/engine.h>

namespace Engine {

    class AioEngine : public Base {
        private:
            io_context_t io_context;
            std::vector<iocb> iocbs;
            std::vector<iocb*> iocb_ptrs;
            std::vector<io_event> io_events;

            std::vector<AioTask> tasks;
            std::vector<uint32_t> available_indexes;

            void nop(Protocol::IORequest& request, uint32_t free_index);
            void fsync(Protocol::IORequest& request, uint32_t free_index);
            void fdatasync(Protocol::IORequest& request, uint32_t free_index);

            void read(Protocol::IORequest& request, uint32_t free_index);
            void write(Protocol::IORequest& request, uint32_t free_index);

            void reap_completions(void);

        public:
            AioEngine(
                Metric::MetricVariant _metric,
                std::shared_ptr<Logger::Base> _logger,
                const AioConfig& _config
            );

            ~AioEngine() override;

            int open(Protocol::OpenRequest& request) override;
            int close(Protocol::CloseRequest& request) override;
            void submit(Protocol::IORequest& request) override;
            void reap_left_completions(void) override;
    };
}

#endif