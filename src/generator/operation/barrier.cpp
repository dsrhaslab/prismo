#include <prismo/generator/operation/barrier.hpp>

namespace Generator {

    Barrier::Barrier(const nlohmann::json& j) {
        threshold = j.at("threshold").get<size_t>();
        barrier_operation = Operation::operation_from_str(
            j.at("operation").get<std::string>()
        );
        trigger_operation = Operation::operation_from_str(
            j.at("trigger").get<std::string>()
        );
    }

    uint64_t Barrier::get_threshold(void) const {
        return threshold;
    }

    uint64_t Barrier::get_counter(void) const {
        return counter;
    }

    Operation::OperationType Barrier::apply(Operation::OperationType operation) {
        if (operation == trigger_operation && counter++ == threshold) {
            counter = 0;
            return barrier_operation;
        }
        return operation;
    }

    MultipleBarrier::~MultipleBarrier() {
        std::cout << "~Destroying MultipleBarrier" << std::endl;
    }

    MultipleBarrier::MultipleBarrier(const nlohmann::json& j) {
        for (const auto& barrier_json : j) {
            barriers.emplace_back(barrier_json);
        }
        std::sort(barriers.begin(), barriers.end(),
            [](const Barrier& a, const Barrier& b) {
                return a.get_threshold() < b.get_threshold();
            });
    }

    Operation::OperationType MultipleBarrier::apply(Operation::OperationType operation) {
        for (auto& barrier : barriers) {
            Operation::OperationType new_operation = barrier.apply(operation);
            if (operation != new_operation) {
                std::sort(barriers.begin(), barriers.end(),
                    [](const Barrier& a, const Barrier& b) {
                        return
                            a.get_threshold() - a.get_counter() <
                            b.get_threshold() - b.get_counter();
                    });
                return new_operation;
            }
        }
        return operation;
    }
}
