#ifndef OPERATION_GENERATOR_H
#define OPERATION_GENERATOR_H

#include <vector>
#include <iostream>
#include <nlohmann/json.hpp>
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

            virtual void validate(void) const = 0;
    };

    class ConstantOperationGenerator : public OperationGenerator {
        private:
            Operation::OperationType operation;

        public:
            ConstantOperationGenerator() = delete;

            ~ConstantOperationGenerator() override {
                std::cout << "~Destroying ConstantOperationGenerator" << std::endl;
            };

            explicit ConstantOperationGenerator(const json& j) {
                std::string op_str = j.at("operation").get<std::string>();
                operation = Operation::operation_from_str(op_str);
            };

            Operation::OperationType next_operation(void) override {
                return operation;
            };

            void validate(void) const override {};
    };

    class PercentageOperationGenerator : public OperationGenerator {
        private:
            std::vector<PercentageElement<uint32_t, Operation::OperationType>> op_percentages;
            Distribution::UniformDistribution<uint32_t> distribution;

        public:
            PercentageOperationGenerator() = delete;

            ~PercentageOperationGenerator() override {
                std::cout << "~Destroying PercentageOperationGenerator" << std::endl;
            };

            explicit PercentageOperationGenerator(const json& j)
                : OperationGenerator(), op_percentages(), distribution(0, 99)
            {
                uint32_t cumulative = 0;
                for (const auto& item: j.at("percentages").items()) {
                    cumulative += item.value().get<uint32_t>();
                    op_percentages.push_back(PercentageElement<uint32_t, Operation::OperationType> {
                        .cumulative_percentage = cumulative,
                        .value = Operation::operation_from_str(item.key()),
                    });
                }
            };


            Operation::OperationType next_operation(void) override {
                uint32_t roll = distribution.nextValue();
                return select_from_percentage_vector(roll, op_percentages);
            };

            void validate(void) const {
                validate_percentage_vector(op_percentages, "percentage_operation");
            };
    };

    class SequenceOperationGeneator : public OperationGenerator {
        private:
            size_t index;
            size_t length;
            std::vector<Operation::OperationType> operations;

        public:
            SequenceOperationGeneator() = delete;

            ~SequenceOperationGeneator() override {
                std::cout << "~Destroying SequenceOperationGeneator" << std::endl;
            };

            explicit SequenceOperationGeneator(const json& j)
                : OperationGenerator(), index(0), length(0), operations()
            {
                for (auto& item : j.at("operations")) {
                    auto op_str = item.get<std::string>();
                    operations.push_back(Operation::operation_from_str(op_str));
                }
                length = operations.size();
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
    };
};

#endif