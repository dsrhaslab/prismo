#ifndef TRACE_BASED_EXTENSION_H
#define TRACE_BASED_EXTENSION_H

#include <iostream>
#include <optional>
#include <vector>
#include <map>
#include <cstdint>
#include <algorithm>
#include <random>
#include <numeric>
#include <common/trace.h>
#include <nlohmann/json.hpp>
#include <prismo/parser/tracereader.h>
#include <lib/distribution/distribution.h>

using json = nlohmann::json;

namespace Extension {

    class TraceExtension {
        protected:
            std::optional<Parser::TraceReader> trace_reader;

            TraceExtension() = delete;

            explicit TraceExtension(const json& j)
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

            explicit RepeatExtension(const json& j)
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
            std::vector<Trace::Record> collected_records;

            // Frequency maps for offset and block_id
            std::map<uint64_t, uint32_t> offset_frequencies;
            std::map<uint64_t, uint32_t> block_id_frequencies;

            // Vectors of actual values for weighted selection
            std::vector<uint64_t> offset_values;
            std::vector<uint32_t> offset_weights;
            std::vector<uint64_t> block_id_values;
            std::vector<uint32_t> block_id_weights;

            // Operation types collected
            std::vector<Operation::OperationType> operation_types;

            // Discrete distributions for weighted sampling
            std::discrete_distribution<size_t> offset_distribution;
            std::discrete_distribution<size_t> block_id_distribution;

            std::mt19937 rng_engine{std::random_device{}()};

            Trace::Record generate_record() {
                Trace::Record generated{};

                // Select offset based on observed frequencies
                if (!offset_values.empty()) {
                    size_t offset_idx = offset_distribution(rng_engine);
                    generated.offset = offset_values[offset_idx];
                } else {
                    generated.offset = 0;
                }

                // Pick an operation type from collected ones
                if (!operation_types.empty()) {
                    size_t op_idx = std::uniform_int_distribution<size_t>(0, operation_types.size() - 1)(rng_engine);
                    generated.operation = operation_types[op_idx];
                } else {
                    generated.operation = Operation::OperationType::READ;
                }

                // Select block_id based on observed frequencies
                if (!block_id_values.empty()) {
                    size_t block_idx = block_id_distribution(rng_engine);
                    generated.block_id = block_id_values[block_idx];
                } else {
                    generated.block_id = 0;
                }

                return generated;
            }

        public:
            SampleExtension() = delete;

            ~SampleExtension() override {
                std::cout << "~Destroying SampleExtension" << std::endl;
            }

            explicit SampleExtension(const json& j)
                : TraceExtension(j) {}

            Trace::Record next_record() override {
                // If we haven't collected properties yet, collect them
                if (!collection_phase_done) {
                    // Try to get one record
                    auto record = trace_reader->next_record();
                    if (record.has_value()) {
                        Trace::Record rec = record.value();
                        collected_records.push_back(rec);

                        // Count frequencies
                        offset_frequencies[rec.offset]++;
                        block_id_frequencies[rec.block_id]++;
                        operation_types.push_back(rec.operation);

                        return record.value();
                    } else {
                        // First null received - finalize collection phase
                        collection_phase_done = true;

                        // Build weighted distributions from frequencies
                        if (!offset_frequencies.empty()) {
                            std::vector<double> offset_probs;
                            for (const auto& [offset, count] : offset_frequencies) {
                                offset_values.push_back(offset);
                                offset_probs.push_back(static_cast<double>(count));
                            }
                            offset_distribution = std::discrete_distribution<size_t>(
                                offset_probs.begin(), offset_probs.end());
                        }

                        if (!block_id_frequencies.empty()) {
                            std::vector<double> block_id_probs;
                            for (const auto& [block_id, count] : block_id_frequencies) {
                                block_id_values.push_back(block_id);
                                block_id_probs.push_back(static_cast<double>(count));
                            }
                            block_id_distribution = std::discrete_distribution<size_t>(
                                block_id_probs.begin(), block_id_probs.end());
                        }

                        // Generate first record
                        return generate_record();
                    }
                }

                // Generation phase - generate new records with preserved properties
                return generate_record();
            }
    };
}

#endif