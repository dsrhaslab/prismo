#ifndef OPERATION_BARRIER_H
#define OPERATION_BARRIER_H

#include <cstdint>
#include <vector>
#include <iostream>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace Generator {

    class Barrier {
        private:
            uint64_t counter;
            uint64_t barrier;
            Operation::OperationType barrier_operation;
            Operation::OperationType trigger_operation;

        public:
            Barrier() = delete;

            explicit Barrier(const json& j) : counter(0) {
                barrier = j.at("barrier").get<size_t>();
                barrier_operation = Operation::operation_from_str(
                    j.at("operation").get<std::string>()
                );
                trigger_operation = Operation::operation_from_str(
                    j.at("trigger").get<std::string>()
                );
            };

            Operation::OperationType apply(Operation::OperationType operation) {
                if (operation == trigger_operation && counter++ == barrier) {
                    counter = 0;
                    return barrier_operation;
                }
                return operation;
            };
    };

    class MultipleBarrier {
        private:
            std::vector<Barrier> barriers;

        public:
            MultipleBarrier() = delete;

            ~MultipleBarrier() {
                std::cout << "~Destroying MultipleBarrier" << std::endl;
            }

            explicit MultipleBarrier(const json& j) : barriers() {
                for (const auto& barrier_json : j) {
                    barriers.emplace_back(barrier_json);
                }
            };

            Operation::OperationType apply(Operation::OperationType operation) {
                for (auto& barrier : barriers) {
                    operation = barrier.apply(operation);
                }
                return operation;
            };
    };

};

#endif