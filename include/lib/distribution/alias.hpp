#ifndef LIB_DISTRIBUTION_ALIAS_H
#define LIB_DISTRIBUTION_ALIAS_H

#include "lib/distribution/distribution.hpp"

namespace Distribution {

    template <typename T>
    class AliasTable {
        private:
            std::vector<T> values;
            std::vector<double> prob;
            std::vector<size_t> alias;

        public:
            AliasTable() = default;

            void build(
                const std::vector<T>& vals,
                const std::vector<uint64_t>& weights
            ) {
                size_t n = vals.size();

                if (n == 0) {
                    return;
                }

                double total = 0.0;
                values = vals;

                prob.resize(n);
                alias.resize(n);

                for (const auto& w : weights) {
                    total += static_cast<double>(w);
                }

                std::vector<double> scaled(n);
                std::vector<size_t> small(n), large(n);

                for (size_t i = 0; i < n; ++i)
                    scaled[i] = static_cast<double>(weights[i]) * n / total;

                for (size_t i = 0; i < n; ++i) {
                    if (scaled[i] < 1.0) {
                        small.push_back(i);
                    } else {
                        large.push_back(i);
                    }
                }

                while (!small.empty() && !large.empty()) {
                    size_t s = small.back(); small.pop_back();
                    size_t l = large.back(); large.pop_back();

                    prob[s]  = scaled[s];
                    alias[s] = l;

                    scaled[l] = (scaled[l] + scaled[s]) - 1.0;

                    if (scaled[l] < 1.0) {
                        small.push_back(l);
                    } else {
                        large.push_back(l);
                    }
                }

                while (!large.empty()) {
                    prob[large.back()] = 1.0;
                    large.pop_back();
                }

                while (!small.empty()) {
                    prob[small.back()] = 1.0;
                    small.pop_back();
                }
            }

            bool empty() const {
                return values.empty();
            }

            T sample() const {
                auto& rng = Distribution::get_shared_engine();
                size_t n = values.size();
                size_t col = std::uniform_int_distribution<size_t>(0, n - 1)(rng);
                double coin = std::uniform_real_distribution<double>(0.0, 1.0)(rng);
                return (coin < prob[col]) ? values[col] : values[alias[col]];
            }
    };
}

#endif
