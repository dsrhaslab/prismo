#ifndef PRISMO_ENGINE_ENGINE_H
#define PRISMO_ENGINE_ENGINE_H

#include <thread>
#include <prismo/logger/logger.h>
#include <prismo/protocol/protocol.h>
#include <prismo/metric/statistics.h>

namespace Engine {

    class Base {
        protected:
            Metric::MetricVariant metric;
            pid_t process_id = 0;
            uint64_t thread_id = 0;

            void record_metric(const Metric::MetricVariant& metric) {
                statistics.record_metric(metric);
            }

            void log_metric(const Metric::MetricVariant& metric) {
                if (logger) logger->info(metric);
            }

        private:
            Metric::Statistics statistics;
            std::shared_ptr<Logger::Base> logger = nullptr;

        public:
            Base(
                Metric::MetricVariant _metric,
                std::shared_ptr<Logger::Base> _logger = nullptr
            ) :
                metric(_metric),
                logger(_logger)
            {
                process_id = ::getpid();
                thread_id =
                    std::hash<std::thread::id>{}(std::this_thread::get_id());
                statistics.start();
            }

            void set_process_id_current(void) { process_id = ::getpid(); }

            void set_thread_id_current(void) {
                thread_id =
                    std::hash<std::thread::id>{}(std::this_thread::get_id());
            }

            virtual ~Base() {
                std::cout << "~Destroying Engine" << std::endl;
                statistics.finish();
                statistics.print_report();
            }

            virtual int open(Protocol::OpenRequest& request) = 0;
            virtual int close(Protocol::CloseRequest& request) = 0;
            virtual void submit(Protocol::IORequest& request) = 0;
            virtual void reap_left_completions(void) = 0;
    };
};

#endif