#include <prismo/operation/synthetic.h>

namespace Operation {

    PercentageOperation::PercentageOperation()
        : Operation(), op_percentages(), distribution(0, 99) {}

    OperationType PercentageOperation::next_operation(void) {
        uint32_t roll = distribution.nextValue();
        return select_from_percentage_vector(roll, op_percentages);
    }

    void PercentageOperation::validate(void) const {
        validate_percentage_vector(op_percentages, "percentage operation");
    }

    void from_json(const json& j, PercentageOperation& op_generator) {
        uint32_t cumulative = 0;

        for (const auto& item: j.at("percentages").items()) {
            std::string operation = item.key();
            cumulative += item.value().template get<uint32_t>();

            PercentageElement<uint32_t, OperationType> element {
                .cumulative_percentage = cumulative,
                .value = operation_from_str(operation)
            };

            op_generator.op_percentages.push_back(element);
        }

        op_generator.validate();
    }
}
