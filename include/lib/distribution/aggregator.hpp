#ifndef LIB_DISTRIBUTION_AGGREGATOR
#define LIB_DISTRIBUTION_AGGREGATOR

#include <vector>
#include <numeric>
#include <algorithm>
#include <iostream>

namespace Distribution {

    template <typename T>
    concept Reducible = requires(T a, T b) {
        { a + b } -> std::same_as<T>;
        { a * b } -> std::same_as<T>;
        { a / b } -> std::same_as<T>;
        T{};
    };

    enum class ReduceOp { Sum, Average };

    template <Reducible T, ReduceOp Op = ReduceOp::Sum>
    class Aggregator {

        private:
            uint64_t start_ns = 0;
            static constexpr uint64_t interval_ns = 1'000'000'000LL;

            std::vector<T> aggregated_values;
            std::vector<size_t> aggregated_counts;
            std::vector<T> pending_values;

            T reduce(const std::vector<T>& vals) const {
                T sum = std::reduce(vals.begin(), vals.end(), T{});
                if constexpr (Op == ReduceOp::Average) {
                    return vals.empty() ? T{} : sum / static_cast<T>(vals.size());
                }
                return sum;
            }

            T merge_reduce(T a, size_t count_a, T b, size_t count_b) const {
                if constexpr (Op == ReduceOp::Average) {
                    size_t total = count_a + count_b;
                    return total > 0
                        ? (a * static_cast<T>(count_a) + b * static_cast<T>(count_b))
                            / static_cast<T>(total)
                        : T{};
                }
                return a + b;
            }

        public:
            Aggregator() = default;

            ~Aggregator() {
                std::cout << "~Destroying Aggregator" << std::endl;
            }

            void start(uint64_t ns) {
                start_ns = ns;
            }

            void record(const T& value, uint64_t timestamp_ns) {
                while (timestamp_ns - start_ns >= interval_ns) {
                    aggregated_values.push_back(reduce(pending_values));
                    aggregated_counts.push_back(pending_values.size());
                    pending_values.clear();
                    start_ns += interval_ns;
                }

                pending_values.push_back(value);
            }

            void flush() {
                if (!pending_values.empty()) {
                    aggregated_values.push_back(reduce(pending_values));
                    aggregated_counts.push_back(pending_values.size());
                    pending_values.clear();
                }
            }

            const std::vector<T>& values() const {
                return aggregated_values;
            }

            void merge(const Aggregator& other) {
                size_t max_size = std::max(
                    aggregated_values.size(),
                    other.aggregated_values.size()
                );
                aggregated_values.resize(max_size, T{});
                aggregated_counts.resize(max_size, 0);

                for (size_t i = 0; i < other.aggregated_values.size(); i++) {
                    aggregated_values[i] = merge_reduce(
                        aggregated_values[i], aggregated_counts[i],
                        other.aggregated_values[i], other.aggregated_counts[i]
                    );
                    aggregated_counts[i] += other.aggregated_counts[i];
                }
            }
    };
}


#endif