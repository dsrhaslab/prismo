#ifndef DISTRIBUTION_H
#define DISTRIBUTION_H

#include <cstdint>
#include <random>
#include <lib/distribution/zipfian.h>

namespace Distribution {

    inline std::mt19937& get_shared_engine() {
        static thread_local std::mt19937 engine(std::random_device{}());
        return engine;
    }

    template <typename DistributionTypeT>
    struct UniformDistribution {
        private:
            std::uniform_int_distribution<DistributionTypeT> distribution;

        public:
            UniformDistribution()
                : distribution(
                    std::numeric_limits<DistributionTypeT>::lowest(),
                    std::numeric_limits<DistributionTypeT>::max() - 1) {}

            UniformDistribution(DistributionTypeT _min, DistributionTypeT _max)
                : distribution(_min, _max) {}

            void setParams(DistributionTypeT _min, DistributionTypeT _max) {
                distribution.param(typename std::uniform_int_distribution<
                                DistributionTypeT>::param_type(_min, _max));
            }

            DistributionTypeT nextValue() {
                return distribution(get_shared_engine());
            }
    };

    template <typename DistributionTypeT>
    struct ZipfianDistribution {
        private:
            zipfian_distribution<DistributionTypeT> distribution;

        public:
            explicit ZipfianDistribution() = default;

            explicit ZipfianDistribution(
                DistributionTypeT lower_bound,
                DistributionTypeT upper_bound,
                float skew
            ) : distribution(lower_bound, upper_bound, skew) {}

            void setParams(DistributionTypeT min, DistributionTypeT max, float skew) {
                distribution.param(typename zipfian_distribution<
                    DistributionTypeT>::param_type(min, max, skew));
            }

            DistributionTypeT nextValue() {
                return distribution(get_shared_engine());
            }
    };

    template <typename DistributionTypeT>
    struct DiscreteDistribution {
        private:
            std::string context_tag;
            std::vector<DistributionTypeT> values;
            std::discrete_distribution<uint32_t> distribution;

        public:
            DiscreteDistribution() = default;

            explicit DiscreteDistribution(
                const std::string& _context_tag,
                const std::vector<DistributionTypeT>& _values,
                const std::vector<uint32_t>& _weights
            ) : context_tag(_context_tag),
                values(_values),
                distribution(_weights.begin(), _weights.end()
            ) {
                if (values.size() != _weights.size()) {
                    throw std::invalid_argument(
                        context_tag + ": number of values must match number of weights");
                }

                if (values.empty() || _weights.empty()) {
                    throw std::invalid_argument(
                        context_tag + ": values and weights cannot be empty");
                }

                if (std::accumulate(_weights.begin(), _weights.end(), 0) != 100) {
                    throw std::invalid_argument(context_tag + ": weights must sum to 100");
                }
            }

            DistributionTypeT nextValue() {
                return values[distribution(get_shared_engine())];
            }
    };
};

#endif