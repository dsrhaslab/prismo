#ifndef PRISMO_GENERATOR_OPERATION_GENERATOR_H
#define PRISMO_GENERATOR_OPERATION_GENERATOR_H

#include <vector>
#include <iostream>
#include <nlohmann/json.hpp>
#include <common/operation.hpp>
#include <lib/distribution/distribution.hpp>

namespace Generator {

    class OperationGenerator {
        protected:
            OperationGenerator() = default;

        public:
            virtual ~OperationGenerator();

            virtual Operation::OperationType next_operation(void) = 0;
    };

    class ConstantOperationGenerator : public OperationGenerator {
        private:
            Operation::OperationType operation;

        public:
            ConstantOperationGenerator() = delete;

            ~ConstantOperationGenerator() override;

            explicit ConstantOperationGenerator(const nlohmann::json& j);

            Operation::OperationType next_operation(void) override;
    };

    class PercentageOperationGenerator : public OperationGenerator {
        private:
            Distribution::DiscreteDistribution<Operation::OperationType> distribution;

        public:
            PercentageOperationGenerator() = delete;

            ~PercentageOperationGenerator() override;

            explicit PercentageOperationGenerator(const nlohmann::json& j);

            Operation::OperationType next_operation(void) override;
    };

    class SequenceOperationGenerator : public OperationGenerator {
        private:
            size_t index = 0;
            std::vector<Operation::OperationType> operations;

        public:
            SequenceOperationGenerator() = delete;

            ~SequenceOperationGenerator() override;

            explicit SequenceOperationGenerator(const nlohmann::json& j);

            Operation::OperationType next_operation(void) override;
    };
};

#endif