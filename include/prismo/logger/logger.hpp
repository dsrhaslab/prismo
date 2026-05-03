#ifndef PRISMO_LOGGER_LOGGER_H
#define PRISMO_LOGGER_LOGGER_H

#include <iostream>
#include <unordered_map>
#include <common/operation.hpp>
#include <prismo/metric/metric.hpp>

namespace Logger {

    class Base {
        private:
            const uint64_t avg_interval_ms;
            std::chrono::steady_clock::time_point last_avg_time;
            std::unordered_map<Operation::OperationType, std::vector<Metric::Metric>> metrics_by_op;

            Metric::Metric compute_average(const std::vector<Metric::Metric>& metrics) const;

        protected:
            virtual void write(const Metric::Metric& metric) = 0;

        public:
            explicit Base(uint64_t _avg_interval_ms);

            virtual ~Base();

            void info(const Metric::Metric& metric);
    };
};

#endif