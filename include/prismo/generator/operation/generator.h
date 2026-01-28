#ifndef OPERATION_GENERATOR_H
#define OPERATION_GENERATOR_H

#include <vector>
#include <iostream>
#include <nlohmann/json.hpp>
#include <prismo/generator/operation/type.h>
#include <lib/distribution/distribution.h>
#include <lib/distribution/percentage.h>

using json = nlohmann::json;

namespace Generator {

    class OperationGenerator {
        public:
            OperationGenerator() = default;

            virtual ~OperationGenerator() {
                std::cout << "~Destroying Operation" << std::endl;
            };

            virtual Operation::OperationType next_operation(void) = 0;
    };

    class ConstantOperationGenerator : public OperationGenerator {
        private:
            Operation::OperationType operation;

        public:
            ConstantOperationGenerator() = default;

            ~ConstantOperationGenerator() override {
                std::cout << "~Destroying ConstantOperationGenerator" << std::endl;
            };

            Operation::OperationType next_operation(void) override {
                return operation;
            };

            friend void from_json(const json& j, ConstantOperationGenerator& operation_generator) {
                std::string operation = j.at("operation").template get<std::string>();
                operation_generator.operation = Operation::operation_from_str(operation);
            };
    };

    class PercentageOperationGenerator : public OperationGenerator {
        private:
            std::vector<PercentageElement<uint32_t, Operation::OperationType>> op_percentages;
            Distribution::UniformDistribution<uint32_t> distribution;

        public:
            PercentageOperationGenerator()
                : OperationGenerator(), op_percentages(), distribution(0, 99) {};

            ~PercentageOperationGenerator() override {
                std::cout << "~Destroying PercentageOperationGenerator" << std::endl;
            }

            Operation::OperationType next_operation(void) override {
                uint32_t roll = distribution.nextValue();
                return select_from_percentage_vector(roll, op_percentages);
            }

            void validate(void) const {
                validate_percentage_vector(op_percentages, "percentage_operation");
            };

            friend void from_json(const json& j, PercentageOperationGenerator& operation_generator) {
                uint32_t cumulative = 0;

                for (const auto& item: j.at("percentages").items()) {
                    std::string operation = item.key();
                    cumulative += item.value().template get<uint32_t>();

                    PercentageElement<uint32_t, Operation::OperationType> element {
                        .cumulative_percentage = cumulative,
                        .value = Operation::operation_from_str(operation)
                    };

                    operation_generator.op_percentages.push_back(element);
                }

                operation_generator.validate();
            };
    };

    class SequenceOperationGeneator : public OperationGenerator {
        private:
            size_t index;
            size_t length;
            std::vector<Operation::OperationType> operations;

        public:
            SequenceOperationGeneator() = default;

            ~SequenceOperationGeneator() override {
                std::cout << "~Destroying SequenceOperationGeneator" << std::endl;
            };

            Operation::OperationType next_operation(void) override{
                Operation::OperationType operation = operations.at(index);
                index = (index + 1) % length;
                return operation;
            };

            void validate(void) const {
                if (operations.size() == 0) {
                    throw std::invalid_argument("validate: invalid sequence of operations");
                }
            };

            friend void from_json(const json& j, SequenceOperationGeneator& operation_generator) {
                for (auto& item : j.at("operations")) {
                    std::string operation = item.template get<std::string>();
                    operation_generator.operations.push_back(Operation::operation_from_str(operation));
                }
                operation_generator.length = operation_generator.operations.size();
                operation_generator.validate();
            };
    };
};

#endif