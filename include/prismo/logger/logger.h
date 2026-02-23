#ifndef LOGGER_H
#define LOGGER_H

#include <iostream>
#include <prismo/io/metric.h>

namespace Logger {

    class Logger {
        public:
            Logger() = default;
            virtual ~Logger() {
                std::cout << "~Destroying Logger" << std::endl;
            }

            virtual void info(const Metric::MetricVariant& metric) = 0;
    };
};

#endif