#include <prismo/generator/tracebased/extension.hpp>

namespace Generator::Extension {

    TraceExtension::TraceExtension(const nlohmann::json& j)
        : trace_reader(j) {}

    TraceExtension::~TraceExtension() {
        std::cout << "~Destroying TraceExtension" << std::endl;
    }

    RepeatExtension::RepeatExtension(const nlohmann::json& j)
        : TraceExtension(j) {}

    RepeatExtension::~RepeatExtension() {
        std::cout << "~Destroying RepeatExtension" << std::endl;
    }

    Trace::Record RepeatExtension::next_record(void) {
        auto record = trace_reader->next_record();
        if (!record.has_value()) {
            trace_reader->reset();
            record = trace_reader->next_record();
        }
        return record.value();
    }

    SampleExtension::SampleExtension(const nlohmann::json& j)
        : TraceExtension(j),
          max_samples(
              j.value("max_samples", Distribution::DEFAULT_RESERVOIR_SIZE)),
          offset_sampler(max_samples),
          block_id_sampler(max_samples) {}

    SampleExtension::~SampleExtension() {
        std::cout << "~Destroying SampleExtension" << std::endl;
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

    RegressionExtension::RegressionExtension(const nlohmann::json& j)
        : TraceExtension(j),
          max_samples(
              j.value("max_samples", Distribution::DEFAULT_RESERVOIR_SIZE))
    {
        offsets.reserve(max_samples);
        operations.reserve(max_samples);
        block_ids.reserve(max_samples);
    }

    RegressionExtension::~RegressionExtension() {
        std::cout << "~Destroying RegressionExtension" << std::endl;
    }

    Eigen::Vector3d RegressionExtension::fit_multiple(
        const Eigen::VectorXd& v1,
        const Eigen::VectorXd& v2,
        const Eigen::VectorXd& target
    ) {
        const int n = static_cast<int>(v1.size());
        Eigen::MatrixXd X(n, 3);
        X << Eigen::VectorXd::Ones(n), v1, v2;
        return X.completeOrthogonalDecomposition().solve(target);
    }

    void RegressionExtension::save_record(const Trace::Record& record) {
        if (offsets.size() < max_samples) {
            offsets.push_back(static_cast<double>(record.offset));
            operations.push_back(static_cast<double>(record.operation));
            block_ids.push_back(static_cast<double>(record.block_id));
        }
    }

    void RegressionExtension::build_model(void) {
        const int n = static_cast<int>(offsets.size());

        Eigen::VectorXd x = Eigen::Map<Eigen::VectorXd>(offsets.data(), n);
        Eigen::VectorXd y = Eigen::Map<Eigen::VectorXd>(operations.data(), n);
        Eigen::VectorXd z = Eigen::Map<Eigen::VectorXd>(block_ids.data(), n);

        // Fit: operation = a(0) + a(1)*offset + a(2)*block_id
        a = fit_multiple(x, z, y);

        // Fit: block_id = b(0) + b(1)*offset + b(2)*operation
        b = fit_multiple(x, y, z);

        // Precompute 2x2 system matrix:
        //   y - a(2)*z = a(0) + a(1)*x   =>  [ 1    -a(2) ] [y]   [a(0)+a(1)*x]
        //  -b(2)*y + z = b(0) + b(1)*x       [-b(2)  1    ] [z] = [b(0)+b(1)*x]
        system_matrix << 1.0, -a(2),
                        -b(2),  1.0;

        // Compute offset stepping parameters from the trace
        if (n > 1) {
            offset_base = x(n - 1);
            offset_step = (x(n - 1) - x(0)) / static_cast<double>(n - 1);
        } else {
            offset_base = x(0);
            offset_step = 1.0;
        }

        // Free collected data – no longer needed
        offsets.clear();
        offsets.shrink_to_fit();

        operations.clear();
        operations.shrink_to_fit();

        block_ids.clear();
        block_ids.shrink_to_fit();
    }

    Trace::Record RegressionExtension::generate_record(void) {
        const double x_new = offset_base + (++generation_counter) * offset_step;

        Eigen::Vector2d rhs;
        rhs << a(0) + a(1) * x_new,
               b(0) + b(1) * x_new;

        Eigen::Vector2d yz = system_matrix.colPivHouseholderQr().solve(rhs);

        Trace::Record record{};
        record.offset    = static_cast<uint64_t>(std::max(0.0, std::round(x_new)));
        record.operation = static_cast<Operation::OperationType>(
            std::clamp(static_cast<int>(std::round(yz(0))),
                       static_cast<int>(Operation::OperationType::READ),
                       static_cast<int>(Operation::OperationType::NOP))
        );
        record.block_id  = static_cast<uint64_t>(std::max(0.0, std::round(yz(1))));

        return record;
    }

    Trace::Record RegressionExtension::next_record(void) {
        if (collection_phase_done) {
            return generate_record();
        }

        auto op_record = trace_reader->next_record();
        if (op_record) {
            save_record(op_record.value());
            return op_record.value();
        }

        collection_phase_done = true;
        build_model();
        return generate_record();
    }
}
