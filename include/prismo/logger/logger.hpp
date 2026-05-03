#ifndef PRISMO_LOGGER_LOGGER_H
#define PRISMO_LOGGER_LOGGER_H

#include <iostream>
#include <unordered_map>
#include <common/operation.hpp>
#include <prismo/metric/metric.hpp>
#include <nlohmann/json.hpp>

namespace Logger {

    class Base {
        private:
            const uint64_t avg_interval_ms;
            std::chrono::steady_clock::time_point last_avg_time;
            std::unordered_map<Operation::OperationType, std::vector<Metric::Metric>> metrics_by_op;

            Metric::Metric merge(const std::vector<Metric::Metric>& metrics) const;

        protected:
            virtual void write(const Metric::Metric& metric) = 0;

        public:
            explicit Base(const nlohmann::json& j);

            virtual ~Base();

            void flush(void);
            void info(const Metric::Metric& metric);
    };
};

#endif