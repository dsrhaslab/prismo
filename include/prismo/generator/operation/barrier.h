#ifndef OPERATION_BARRIER_H
#define OPERATION_BARRIER_H

#include <cstdint>
#include <vector>
#include <iostream>
#include <nlohmann/json.hpp>
#include <prismo/generator/operation/type.h>

using json = nlohmann::json;

namespace Generator {

    class Barrier {
        private:
            uint64_t counter = 0;
            uint64_t everyN;
            Operation::OperationType barrier_operation;
            Operation::OperationType trigger_operation;

        public:
            Barrier() = default;

            Barrier(
                size_t _everyN,
                Operation::OperationType _barrier_operation,
                Operation::OperationType _trigger_operation
            ) :
                counter(0),
                everyN(_everyN),
                barrier_operation(_barrier_operation),
                trigger_operation(_trigger_operation) {};

            Operation::OperationType apply(Operation::OperationType operation) {
                if (operation == trigger_operation && counter++ == everyN) {
                    counter = 0;
                    return barrier_operation;
                }
                return operation;
            };

            friend void from_json(const json& j, Barrier& barrier) {
                j.at("counter").get_to(barrier.everyN);
                barrier.barrier_operation = Operation::operation_from_str(
                    j.at("operation").template get<std::string>()
                );
                barrier.trigger_operation = Operation::operation_from_str(
                    j.at("trigger").template get<std::string>()
                );
            };
    };

    class MultipleBarrier {
        private:
            std::vector<Barrier> barriers;

        public:
            MultipleBarrier() = default;

            ~MultipleBarrier() {
                std::cout << "~Destroying MultipleBarrier" << std::endl;
            }

            void addBarrier(Barrier barrier) {
                barriers.push_back(barrier);
            }

            Operation::OperationType apply(Operation::OperationType operation) {
                for (auto& barrier : barriers) {
                    operation = barrier.apply(operation);
                }
                return operation;
            };

            friend void from_json(const json& j, MultipleBarrier& multiple_barrier) {
                for (const auto& barrier : j) {
                    multiple_barrier.barriers.push_back(
                        barrier.template get<Barrier>()
                    );
                }
            };
    };

};

#endif