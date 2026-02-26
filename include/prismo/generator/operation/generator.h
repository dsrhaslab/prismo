#ifndef PRISMO_GENERATOR_OPERATION_GENERATOR_H
#define PRISMO_GENERATOR_OPERATION_GENERATOR_H

#include <vector>
#include <iostream>
#include <nlohmann/json.hpp>
#include <common/operation.h>
#include <lib/distribution/distribution.h>

namespace Generator {

    class OperationGenerator {
        protected:
            OperationGenerator() = default;

        public:
            virtual ~OperationGenerator() {
                std::cout << "~Destroying Operation" << std::endl;
            };

            virtual Operation::OperationType next_operation(void) = 0;
    };

    class ConstantOperationGenerator : public OperationGenerator {
        private:
            Operation::OperationType operation;

        public:
            ConstantOperationGenerator() = delete;

            ~ConstantOperationGenerator() override {
                std::cout << "~Destroying ConstantOperationGenerator" << std::endl;
            };

            explicit ConstantOperationGenerator(const nlohmann::json& j) {
                std::string op_str = j.at("operation").get<std::string>();
                operation = Operation::operation_from_str(op_str);
            };

            Operation::OperationType next_operation(void) override {
                return operation;
            };
    };

    class PercentageOperationGenerator : public OperationGenerator {
        private:
            Distribution::DiscreteDistribution<Operation::OperationType> distribution;

        public:
            PercentageOperationGenerator() = delete;

            ~PercentageOperationGenerator() override {
                std::cout << "~Destroying PercentageOperationGenerator" << std::endl;
            };

            explicit PercentageOperationGenerator(const nlohmann::json& j)
                : distribution(
                    [&]() {
                        std::vector<uint32_t> weights;
                        std::vector<Operation::OperationType> values;
                        for (const auto& item : j.at("percentages").items()) {
                            weights.push_back(item.value().get<uint32_t>());
                            values.push_back(Operation::operation_from_str(item.key()));
                        }
                        return Distribution::DiscreteDistribution<
                            Operation::OperationType>(
                            "percentage_operation_generator", values, weights);
                    }()
                )
            {}

            Operation::OperationType next_operation(void) override {
                return distribution.nextValue();
            };
    };

    class SequenceOperationGenerator : public OperationGenerator {
        private:
            size_t index = 0;
            std::vector<Operation::OperationType> operations;

        public:
            SequenceOperationGenerator() = delete;

            ~SequenceOperationGenerator() override {
                std::cout << "~Destroying SequenceOperationGenerator" << std::endl;
            };

            explicit SequenceOperationGenerator(const nlohmann::json& j) {
                for (auto& item : j.at("operations")) {
                    auto op_str = item.get<std::string>();
                    operations.push_back(Operation::operation_from_str(op_str));
                }

                if (operations.empty()) {
                    throw std::invalid_argument("SequenceOperationGenerator: operations cannot be empty");
                }
            };

            Operation::OperationType next_operation(void) override {
                Operation::OperationType operation = operations.at(index);
                index = (index + 1) % operations.size();
                return operation;
            };
    };
};

#endif