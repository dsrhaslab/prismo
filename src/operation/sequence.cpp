#include <prismo/operation/synthetic.h>

namespace Operation {

    SequenceOperation::SequenceOperation()
        : Operation(), index(0), length(0), operations() {}

    OperationType SequenceOperation::next_operation(void) {
        OperationType operation = operations.at(index);
        index = (index + 1) % length;
        return operation;
    }

    void SequenceOperation::validate(void) const {
        if (operations.size() == 0) {
            throw std::invalid_argument("validate: invalid sequence of operations");
        }
    }

    void from_json(const json& j, SequenceOperation& op_generator) {
        for (auto& item : j.at("operations")) {
            std::string operation = item.template get<std::string>();
            op_generator.operations.push_back(operation_from_str(operation));
        }
        op_generator.length = op_generator.operations.size();
        op_generator.validate();
    }
}