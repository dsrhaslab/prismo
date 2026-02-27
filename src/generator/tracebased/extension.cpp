#include <prismo/generator/tracebased/extension.hpp>

namespace Generator::Extension {

    TraceExtension::TraceExtension(const nlohmann::json& j)
        : trace_reader(j) {}

    TraceExtension::~TraceExtension() {
        std::cout << "~Destroying TraceExtension" << std::endl;
    }

    RepeatExtension::~RepeatExtension() {
        std::cout << "~Destroying RepeatExtension" << std::endl;
    }

    RepeatExtension::RepeatExtension(const nlohmann::json& j)
        : TraceExtension(j) {}

    Trace::Record RepeatExtension::next_record(void) {
        auto record = trace_reader->next_record();
        if (!record.has_value()) {
            trace_reader->reset();
            record = trace_reader->next_record();
        }
        return record.value();
    }

    void SampleExtension::save_record(const Trace::Record& record) {
        offset_sampler.insert(record.offset);
        block_id_sampler.insert(record.block_id);
        operation_frequencies[record.operation]++;
    }

    void SampleExtension::build_alias_tables() {
        offset_alias = offset_sampler.build_alias();
        block_id_alias = block_id_sampler.build_alias();

        std::vector<uint64_t> op_weights;
        std::vector<Operation::OperationType> op_vals;

        for (const auto& [op, count] : operation_frequencies) {
            op_vals.push_back(op);
            op_weights.push_back(count);
        }

        operation_alias.build(op_vals, op_weights);
    }

    Trace::Record SampleExtension::generate_record(void) {
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

    SampleExtension::~SampleExtension() {
        std::cout << "~Destroying SampleExtension" << std::endl;
    }

    SampleExtension::SampleExtension(const nlohmann::json& j)
        : TraceExtension(j),
        offset_sampler(j.value("sample_size", RESERVOIR_SIZE)),
        block_id_sampler(j.value("sample_size", RESERVOIR_SIZE)) {}

    Trace::Record SampleExtension::next_record() {
        if (collection_phase_done) {
            return generate_record();
        }

        auto op_record = trace_reader->next_record();
        if (op_record) {
            save_record(op_record.value());
            return op_record.value();
        }

        collection_phase_done = true;

        build_alias_tables();
        return generate_record();
    }
}
