#ifndef PRISMO_GENERATOR_TRACEBASED_EXTENSION_H
#define PRISMO_GENERATOR_TRACEBASED_EXTENSION_H

#include <iostream>
#include <optional>
#include <vector>
#include <map>
#include <cstdint>
#include <Eigen/Dense>
#include <prismo/generator/tracebased/tracereader.hpp>
#include <lib/distribution/alias.hpp>
#include <lib/distribution/reservoir.hpp>
#include <lib/distribution/distribution.hpp>

namespace Generator::Extension {

    class TraceExtension {
        protected:
            std::optional<Generator::Parser::TraceReader> trace_reader;

            TraceExtension() = delete;

            explicit TraceExtension(const nlohmann::json& j);

        public:
            virtual ~TraceExtension();

            virtual Trace::Record next_record() = 0;
    };

    class RepeatExtension : public TraceExtension {
        public:
            RepeatExtension() = delete;

            ~RepeatExtension() override;

            explicit RepeatExtension(const nlohmann::json& j);

            Trace::Record next_record(void) override;
    };

    class SampleExtension : public TraceExtension {
        private:
            bool collection_phase_done = false;
            size_t max_samples = Distribution::DEFAULT_RESERVOIR_SIZE;

            Distribution::ReservoirSampler<uint64_t> offset_sampler;
            Distribution::ReservoirSampler<uint64_t> block_id_sampler;
            std::map<Operation::OperationType, uint64_t> operation_frequencies;

            Distribution::AliasTable<uint64_t> offset_alias;
            Distribution::AliasTable<uint64_t> block_id_alias;
            Distribution::AliasTable<Operation::OperationType> operation_alias;

            void save_record(const Trace::Record& record);

            void build_alias_tables(void);

            Trace::Record generate_record(void);

        public:
            SampleExtension() = delete;

            ~SampleExtension() override;

            explicit SampleExtension(const nlohmann::json& j);

            Trace::Record next_record() override;
    };

    class RegressionExtension : public TraceExtension {
        private:
            bool collection_phase_done = false;
            size_t max_samples = Distribution::DEFAULT_RESERVOIR_SIZE;

            // Collected data vectors
            std::vector<double> offsets;
            std::vector<double> operations;
            std::vector<double> block_ids;

            // Regression coefficients
            // operation = a(0) + a(1)*offset + a(2)*block_id
            Eigen::Vector3d a;
            // block_id  = b(0) + b(1)*offset + b(2)*operation
            Eigen::Vector3d b;

            // Precomputed 2x2 system matrix for generation phase
            Eigen::Matrix2d system_matrix;

            // Counter used to generate new offsets beyond trace range
            uint64_t generation_counter = 0;
            double offset_step = 1.0;
            double offset_base = 0.0;

            // Fit: target = beta[0] + beta[1]*v1 + beta[2]*v2
            static Eigen::Vector3d fit_multiple(
                const Eigen::VectorXd& v1,
                const Eigen::VectorXd& v2,
                const Eigen::VectorXd& target
            );

            void save_record(const Trace::Record& record);

            void build_model(void);

            Trace::Record generate_record(void);

        public:
            RegressionExtension() = delete;

            ~RegressionExtension() override;

            explicit RegressionExtension(const nlohmann::json& j);

            Trace::Record next_record(void) override;
    };
}

#endif