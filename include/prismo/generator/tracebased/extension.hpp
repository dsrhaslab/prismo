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
            static constexpr size_t RESERVOIR_SIZE = 1e6;

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
}

#endif