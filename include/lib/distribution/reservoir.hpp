#ifndef LIB_DISTRIBUTION_RESERVOIR_H
#define LIB_DISTRIBUTION_RESERVOIR_H

#include <vector>
#include <cstdint>
#include <algorithm>
#include <random>
#include <lib/distribution/alias.hpp>
#include <lib/distribution/distribution.hpp>

namespace Distribution {

    inline constexpr size_t DEFAULT_RESERVOIR_SIZE = 1e6;

    template <typename T>
    class ReservoirSampler {
        private:
            size_t capacity;
            uint64_t count = 0;
            std::vector<T> reservoir;
            std::uniform_int_distribution<size_t> dist;

        public:
            ReservoirSampler() = delete;

            explicit ReservoirSampler(size_t capacity = DEFAULT_RESERVOIR_SIZE)
                : capacity(capacity) {
                reservoir.reserve(capacity);
            }

            void insert(T value) {
                count++;
                if (reservoir.size() < capacity) {
                    reservoir.push_back(value);
                } else {
                    dist.param(
                        std::uniform_int_distribution<size_t>::param_type(
                            0, count - 1));
                    size_t j = dist(Distribution::get_shared_engine());
                    if (j < capacity) {
                        reservoir[j] = value;
                    }
                }
            }

            AliasTable<T> build_alias() {
                AliasTable<T> table;

                if (reservoir.empty()) {
                    return table;
                }

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

                reservoir.clear();
                reservoir.shrink_to_fit();

                return table;
            }
    };
}

#endif
