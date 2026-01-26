#include <prismo/operation/barrier.h>

namespace Operation {

    BarrierCounter::BarrierCounter(
        OperationType _barrier_op,
        OperationType _trigger_op,
        uint64_t _every_n
    ) :
        barrierOp(_barrier_op),
        triggerOp(_trigger_op),
        everyN(_every_n),
        counter(0) {}

    OperationType BarrierCounter::apply(OperationType operation) {
        if (operation == triggerOp && counter++ == everyN) {
            counter = 0;
            return barrierOp;
        }
        return operation;
    }

    void MultipleBarrier::addBarrier(
        OperationType barrier_op,
        OperationType trigger_op,
        uint64_t every_n
    ) {
        barriers.emplace_back(barrier_op, trigger_op, every_n);
    }

    OperationType MultipleBarrier::apply(OperationType operation) {
        for (auto& barrier : barriers) {
            operation = barrier.apply(operation);
        }
        return operation;
    }

    void from_json(const json& j, MultipleBarrier& multiple_barrier) {
        for (const auto& barrier : j) {
            std::string operation = barrier.at("operation").template get<std::string>();
            std::string trigger = barrier.at("trigger").template get<std::string>();
            uint64_t counter = barrier.at("counter").template get<uint64_t>();

            multiple_barrier.addBarrier(
                operation_from_str(operation),
                operation_from_str(trigger),
                counter
            );
        }
    }
};