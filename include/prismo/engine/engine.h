#ifndef ENGINE_H
#define ENGINE_H

#include <vector>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <memory>
#include <iostream>
#include <stdexcept>
#include <prismo/io/metric.h>
#include <prismo/io/protocol.h>
#include <prismo/engine/utils.h>
#include <prismo/logger/logger.h>
#include <prismo/generator/operation/type.h>

namespace Engine {

    class Engine {
        protected:
            std::unique_ptr<Metric::Metric> metric;
            std::unique_ptr<Logger::Logger> logger;

        public:
            Engine(
                std::unique_ptr<Metric::Metric> _metric,
                std::unique_ptr<Logger::Logger> _logger
            ) :
                metric(std::move(_metric)),
                logger(std::move(_logger)) {}

            virtual ~Engine() {
                std::cout << "~Destroying Engine" << std::endl;
            }

            virtual int open(Protocol::OpenRequest& request) = 0;
            virtual int close(Protocol::CloseRequest& request) = 0;
            virtual void submit(Protocol::CommonRequest& request) = 0;
            virtual void reap_left_completions(void) = 0;
    };
};

#endif