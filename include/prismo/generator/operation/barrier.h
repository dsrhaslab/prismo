#ifndef OPERATION_BARRIER_H
#define OPERATION_BARRIER_H

#include <common/operation.h>
#include <cstdint>
#include <iostream>
#include <nlohmann/json.hpp>
#include <vector>

using json = nlohmann::json;

namespace Generator {

    class Barrier {
       private:
        uint64_t counter;
        uint64_t threshold;

        Operation::OperationType barrier_operation;
        Operation::OperationType trigger_operation;

       public:
        Barrier() = delete;

        explicit Barrier(const json& j) : counter(0) {
            threshold = j.at("threshold").get<size_t>();
            barrier_operation = Operation::operation_from_str(
                j.at("operation").get<std::string>());
            trigger_operation = Operation::operation_from_str(
                j.at("trigger").get<std::string>());
        };

        uint64_t get_threshold(void) const { return threshold; }

        uint64_t get_counter(void) const { return counter; }

        Operation::OperationType apply(Operation::OperationType operation) {
            if (operation == trigger_operation && counter++ == threshold) {
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
            std::sort(barriers.begin(), barriers.end(),
                      [](const Barrier& a, const Barrier& b) {
                          return a.get_threshold() < b.get_threshold();
                      });
        };

        Operation::OperationType apply(Operation::OperationType operation) {
            for (auto& barrier : barriers) {
                Operation::OperationType new_operation =
                    barrier.apply(operation);
                if (operation != new_operation) {
                    std::sort(barriers.begin(), barriers.end(),
                              [](const Barrier& a, const Barrier& b) {
                                  return a.get_threshold() - a.get_counter() <
                                         b.get_threshold() - b.get_counter();
                              });
                    return new_operation;
                }
            }
            return operation;
        };
    };

};  // namespace Generator

#endif