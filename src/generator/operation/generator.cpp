#include <prismo/generator/operation/generator.hpp>

namespace Generator {

    OperationGenerator::~OperationGenerator() {
        std::cout << "~Destroying Operation" << std::endl;
    }

    ConstantOperationGenerator::~ConstantOperationGenerator() {
        std::cout << "~Destroying ConstantOperationGenerator" << std::endl;
    }

    ConstantOperationGenerator::ConstantOperationGenerator(const nlohmann::json& j) {
        std::string op_str = j.at("operation").get<std::string>();
        operation = Operation::operation_from_str(op_str);
    }

    Operation::OperationType ConstantOperationGenerator::next_operation(void) {
        return operation;
    }

    PercentageOperationGenerator::~PercentageOperationGenerator() {
        std::cout << "~Destroying PercentageOperationGenerator" << std::endl;
    }

    PercentageOperationGenerator::PercentageOperationGenerator(const nlohmann::json& j)
        : distribution(
            [&]() {
                std::vector<uint32_t> weights;
                std::vector<Operation::OperationType> values;
                for (const auto& item : j.at("percentages").items()) {
                    weights.push_back(item.value().get<uint32_t>());
                    values.push_back(Operation::operation_from_str(item.key()));
                }
                return Distribution::DiscreteDistribution<Operation::OperationType>(
                    "percentage_operation_generator", values, weights);
            }()
        ) {}

    Operation::OperationType PercentageOperationGenerator::next_operation(void) {
        return distribution.nextValue();
    }

    SequenceOperationGenerator::~SequenceOperationGenerator() {
        std::cout << "~Destroying SequenceOperationGenerator" << std::endl;
    }

    SequenceOperationGenerator::SequenceOperationGenerator(const nlohmann::json& j) {
        for (auto& item : j.at("operations")) {
            auto op_str = item.get<std::string>();
            operations.push_back(Operation::operation_from_str(op_str));
        }

        if (operations.empty()) {
            throw std::invalid_argument("SequenceOperationGenerator: operations cannot be empty");
        }
    }

    Operation::OperationType SequenceOperationGenerator::next_operation(void) {
        Operation::OperationType operation = operations.at(index);
        index = (index + 1) % operations.size();
        return operation;
    }
}
