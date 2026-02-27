#ifndef PRISMO_LOGGER_LOGGER_H
#define PRISMO_LOGGER_LOGGER_H

#include <iostream>
#include <prismo/metric/metric.hpp>

namespace Logger {

    class Base {
        public:
            Base() = default;
            virtual ~Base() {
                std::cout << "~Destroying Logger" << std::endl;
            }

            virtual void info(const Metric::MetricVariant& metric) = 0;
    };
};




#endif