#ifndef DISTRIBUTION_H
#define DISTRIBUTION_H

#include <random>
#include <cstdint>
#include <lib/shishua/utils.h>
#include <lib/shishua/shishua.h>
#include <lib/distribution/zipfian.h>

#define UNIFORM_BUFFER_CAPACITY 1024

namespace Distribution {

    inline std::mt19937& get_shared_engine() {
        static thread_local std::mt19937 engine(std::random_device{}());
        return engine;
    }

    template<typename DistributionTypeT>
    struct UniformDistribution {
        private:
            DistributionTypeT min;
            DistributionTypeT max;

            size_t current;
            prng_state shishua_prng;
            std::vector<DistributionTypeT> buffer;

        public:
            UniformDistribution() :
                min(std::numeric_limits<DistributionTypeT>::lowest()),
                max(std::numeric_limits<DistributionTypeT>::max() - 1),
                current(0),
                buffer(UNIFORM_BUFFER_CAPACITY)
            {
                prng_init(&shishua_prng, generate_seed().data());
            }

            UniformDistribution(DistributionTypeT _min, DistributionTypeT _max)
                : min(_min), max(_max), current(0), buffer(UNIFORM_BUFFER_CAPACITY)
            {
                prng_init(&shishua_prng, generate_seed().data());
            }

            void setParams(DistributionTypeT _min, DistributionTypeT _max) {
                min = _min;
                max = _max;
            }

            DistributionTypeT nextValue() {
                if (current == 0) {
                    current = UNIFORM_BUFFER_CAPACITY - 1;
                    prng_gen(
                        &shishua_prng,
                        reinterpret_cast<uint8_t*>(buffer.data()),
                        buffer.size() * sizeof(DistributionTypeT)
                    );
                }
                DistributionTypeT value = buffer[current--];
                DistributionTypeT range = max - min + 1;
                return static_cast<DistributionTypeT>(min + (value % range));
            }
    };

    template<typename DistributionTypeT>
    struct ZipfianDistribution {
        private:
            zipfian_distribution<DistributionTypeT> distribution;

        public:
            explicit ZipfianDistribution() = default;

            explicit ZipfianDistribution(DistributionTypeT lower_bound, DistributionTypeT upper_bound, float skew)
                : distribution(lower_bound, upper_bound, skew) {}

            void setParams(DistributionTypeT min, DistributionTypeT max, float skew) {
                distribution.param(typename zipfian_distribution<DistributionTypeT>::param_type(min, max, skew));
            }

            DistributionTypeT nextValue() {
                return distribution(get_shared_engine());
            }
    };

    template<typename DistributionTypeT>
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
            ) :
                context_tag(_context_tag),
                values(_values),
                distribution(_weights.begin(), _weights.end())
            {
                if (values.size() != _weights.size()) {
                    throw std::invalid_argument(context_tag + ": number of values must match number of weights");
                }

                if (values.empty() || _weights.empty()) {
                    throw std::invalid_argument(context_tag + ": values and weights cannot be empty");
                }

                if (std::ranges::any_of(_weights, [](uint32_t w) { return w == 0; })) {
                    throw std::invalid_argument(context_tag + ": weights must be positive");
                }

                if (std::ranges::any_of(_weights, [](uint32_t w) { return w > 100; })) {
                    throw std::invalid_argument(context_tag + ": weights must be less than or equal to 100");
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