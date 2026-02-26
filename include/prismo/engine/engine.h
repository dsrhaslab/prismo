#ifndef PRISMO_ENGINE_ENGINE_H
#define PRISMO_ENGINE_ENGINE_H

#include <vector>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <memory>
#include <iostream>
#include <stdexcept>
#include <prismo/metric/metric.h>
#include <prismo/protocol/protocol.h>
#include <prismo/metric/statistics.h>
#include <prismo/engine/config.h>
#include <prismo/logger/logger.h>

namespace Engine {

    class Base {
        protected:
            Metric::MetricVariant metric;

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
                statistics.start();
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