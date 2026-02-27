#ifndef LIB_DISTRIBUTION_RESERVOIR_H
#define LIB_DISTRIBUTION_RESERVOIR_H

#include <vector>
#include <cstdint>
#include <algorithm>
#include <random>
#include <lib/distribution/alias.hpp>
#include <lib/distribution/distribution.hpp>

namespace Distribution {

    // Reservoir sampler (Algorithm R) with bounded memory.
    // Collects up to CAPACITY samples online; frequent values naturally
    // occupy more slots. After collection, the reservoir can be converted
    // into an AliasTable for O(1) weighted generation.
    template <typename T>
    class ReservoirSampler {
        private:
            size_t capacity;
            uint64_t count = 0;
            std::vector<T> reservoir;

        public:
            explicit ReservoirSampler(size_t capacity)
                : capacity(capacity) {
                reservoir.reserve(capacity);
            }

            ReservoirSampler() : capacity(0) {}

            // Feed one observed value. O(1) amortized.
            void insert(T value) {
                count++;
                if (reservoir.size() < capacity) {
                    reservoir.push_back(value);
                } else {
                    auto& rng = Distribution::get_shared_engine();
                    uint64_t j = std::uniform_int_distribution<uint64_t>(
                        0, count - 1)(rng);
                    if (j < capacity) {
                        reservoir[j] = value;
                    }
                }
            }

            // Build an AliasTable from the reservoir contents.
            // Counts unique values in the reservoir to derive weights.
            // Clears the reservoir afterwards to free memory.
            AliasTable<T> build_alias() {
                AliasTable<T> table;
                if (reservoir.empty()) return table;

                std::sort(reservoir.begin(), reservoir.end());

                std::vector<T> vals;
                std::vector<uint64_t> weights;
                vals.push_back(reservoir[0]);
                weights.push_back(1);

                for (size_t i = 1; i < reservoir.size(); ++i) {
                    if (reservoir[i] == reservoir[i - 1]) {
                        weights.back()++;
                    } else {
                        vals.push_back(reservoir[i]);
                        weights.push_back(1);
                    }
                }

                table.build(vals, weights);

                // Free reservoir memory
                reservoir.clear();
                reservoir.shrink_to_fit();

                return table;
            }

            bool empty() const { return reservoir.empty(); }
            size_t size() const { return reservoir.size(); }
    };

} // namespace Distribution

#endif
