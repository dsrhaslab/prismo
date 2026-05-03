#ifndef PRISMO_ENGINE_ENGINE_H
#define PRISMO_ENGINE_ENGINE_H

#include <thread>
#include <prismo/logger/logger.hpp>
#include <prismo/protocol/protocol.hpp>
#include <prismo/metric/statistics.hpp>

namespace Engine {

    class Base {
        protected:
            pid_t process_id = 0;
            uint64_t thread_id = 0;

            Base() = delete;

            explicit Base(
                std::unique_ptr<Logger::Base> _logger
            );

            void record_metric(const Metric::Metric& metric);
            void log_metric(const Metric::Metric& metric);

        private:
            Metric::Statistics statistics;
            std::unique_ptr<Logger::Base> logger;

        public:
            virtual ~Base();

            void set_thread_id_current(void);
            void set_process_id_current(void);

            void start_statistics(void);
            void finish_statistics(void);

            void flush_logger(void);
            const Metric::Statistics get_statistics(void) const;

            virtual int open(Protocol::OpenRequest& request) = 0;
            virtual int close(Protocol::CloseRequest& request) = 0;
            virtual void submit(Protocol::IORequest& request) = 0;
            virtual void reap_left_completions(void) = 0;
    };
};

#endif