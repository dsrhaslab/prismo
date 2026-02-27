#ifndef PRISMO_GENERATOR_OPERATION_BARRIER_H
#define PRISMO_GENERATOR_OPERATION_BARRIER_H

#include <cstdint>
#include <vector>
#include <iostream>
#include <nlohmann/json.hpp>
#include <common/operation.hpp>

namespace Generator {

    class Barrier {
        private:
            uint64_t counter = 0;
            uint64_t threshold;

            Operation::OperationType barrier_operation;
            Operation::OperationType trigger_operation;

        public:
            Barrier() = delete;

            explicit Barrier(const nlohmann::json& j);

            uint64_t get_threshold(void) const;

            uint64_t get_counter(void) const;

            Operation::OperationType apply(Operation::OperationType operation);
    };

    class MultipleBarrier {
        private:
            std::vector<Barrier> barriers;

        public:
            MultipleBarrier() = delete;

            ~MultipleBarrier();

            explicit MultipleBarrier(const nlohmann::json& j);

            Operation::OperationType apply(Operation::OperationType operation);
    };

};

#endif