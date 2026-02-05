#ifndef LOGGER_H
#define LOGGER_H

#include <prismo/io/metric.h>
#include <iostream>

namespace Logger {

    class Logger {
       public:
        Logger() = default;
        virtual ~Logger() { std::cout << "~Destroying Logger" << std::endl; }

        virtual void info(Metric::Metric& metric) = 0;
    };
};  // namespace Logger

#endif