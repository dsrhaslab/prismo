#ifndef PERCENTAGE_DISTRIBUTION_H
#define PERCENTAGE_DISTRIBUTION_H

template<typename PercentageT, typename ValueT>
struct PercentageElement {
    PercentageT cumulative_percentage;
    ValueT value;
};

template <typename PercentageT, typename ValueT>
inline ValueT select_from_percentage_vector(
    PercentageT roll,
    const std::vector<PercentageElement<PercentageT, ValueT>>& items
) {
    for (const auto& item : items) {
        if (roll < item.cumulative_percentage) {
            return item.value;
        }
    }
    throw std::runtime_error("select_from_percentage_vector: roll out of range");
}

template <typename PercentageT, typename ValueT>
inline void validate_percentage_vector(
    const std::vector<PercentageElement<PercentageT, ValueT>>& vec,
    const std::string& name
) {
    if (!std::ranges::is_sorted(vec, {},
        &PercentageElement<PercentageT, ValueT>::cumulative_percentage))
    {
        throw std::invalid_argument(
            "validate_percentage_vector: " + name + " cumulative percentage not increasing"
        );
    }

    if (!vec.empty() && vec.back().cumulative_percentage != 100) {
        throw std::invalid_argument(
            "validate_percentage_vector: " + name + " cumulative percentage not equal to 100"
        );
    }
}

#endif
