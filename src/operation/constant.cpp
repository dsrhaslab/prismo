#include <prismo/operation/synthetic.h>

namespace Operation {

    ConstantOperation::ConstantOperation()
        : Operation(), operation(OperationType::READ) {}

    OperationType ConstantOperation::next_operation(void) {
        return operation;
    }

    void from_json(const json& j, ConstantOperation& op_generator) {
        std::string operation = j.at("operation").template get<std::string>();
        op_generator.operation = operation_from_str(operation);
    }
}