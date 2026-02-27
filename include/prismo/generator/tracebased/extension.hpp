#ifndef PRISMO_GENERATOR_TRACEBASED_EXTENSION_H
#define PRISMO_GENERATOR_TRACEBASED_EXTENSION_H

#include <iostream>
#include <optional>
#include <vector>
#include <map>
#include <cstdint>
#include <prismo/generator/tracebased/tracereader.hpp>
#include <lib/distribution/alias.hpp>
#include <lib/distribution/reservoir.hpp>
#include <lib/distribution/distribution.hpp>

namespace Generator::Extension {

    class TraceExtension {
        protected:
            std::optional<Generator::Parser::TraceReader> trace_reader;

            TraceExtension() = delete;

            explicit TraceExtension(const nlohmann::json& j)
                : trace_reader(j) {}

        public:
            virtual ~TraceExtension() {
                std::cout << "~Destroying TraceExtension" << std::endl;
            }

            virtual Trace::Record next_record() = 0;
    };

    class RepeatExtension : public TraceExtension {
        public:
            RepeatExtension() = delete;

            ~RepeatExtension() override {
                std::cout << "~Destroying RepeatExtension" << std::endl;
            }

            explicit RepeatExtension(const nlohmann::json& j)
                : TraceExtension(j) {}

            Trace::Record next_record() override {
                auto record = trace_reader->next_record();
                if (!record.has_value()) {
                    trace_reader->reset();
                    record = trace_reader->next_record();
                }
                return record.value();
            }
    };

    class SampleExtension : public TraceExtension {
        private:
            bool collection_phase_done = false;
            static constexpr size_t RESERVOIR_SIZE = 100'000;

            // Phase 1: reservoir samplers collect bounded samples online
            Distribution::ReservoirSampler<uint64_t> offset_sampler{RESERVOIR_SIZE};
            Distribution::ReservoirSampler<uint64_t> block_id_sampler{RESERVOIR_SIZE};
            std::map<Operation::OperationType, uint64_t> operation_frequencies;

            // Phase 2: alias tables for O(1) weighted generation
            Distribution::AliasTable<uint64_t> offset_alias;
            Distribution::AliasTable<uint64_t> block_id_alias;
            Distribution::AliasTable<Operation::OperationType> operation_alias;

            Trace::Record generate_record() {
                Trace::Record generated{};

                generated.offset = !offset_alias.empty()
                    ? offset_alias.sample() : 0;

                generated.operation = !operation_alias.empty()
                    ? operation_alias.sample()
                    : Operation::OperationType::READ;

                generated.block_id = !block_id_alias.empty()
                    ? block_id_alias.sample() : 0;

                return generated;
            }

        public:
            SampleExtension() = delete;

            ~SampleExtension() override {
                std::cout << "~Destroying SampleExtension" << std::endl;
            }

            explicit SampleExtension(const nlohmann::json& j)
                : TraceExtension(j) {}

            Trace::Record next_record() override {
                if (!collection_phase_done) {
                    auto record = trace_reader->next_record();
                    if (record.has_value()) {
                        Trace::Record rec = record.value();

                        offset_sampler.insert(rec.offset);
                        block_id_sampler.insert(rec.block_id);
                        operation_frequencies[rec.operation]++;

                        return rec;
                    } else {
                        // EOF — build alias tables, free samplers
                        collection_phase_done = true;

                        offset_alias   = offset_sampler.build_alias();
                        block_id_alias = block_id_sampler.build_alias();

                        // Build operation alias from exact frequency counts
                        std::vector<Operation::OperationType> op_vals;
                        std::vector<uint64_t> op_weights;
                        for (const auto& [op, count] : operation_frequencies) {
                            op_vals.push_back(op);
                            op_weights.push_back(count);
                        }
                        operation_alias.build(op_vals, op_weights);
                        operation_frequencies.clear();

                        return generate_record();
                    }
                }

                return generate_record();
            }
    };
}

#endif