#ifndef DISTRIBUTION_H
#define DISTRIBUTION_H

#include <array>
#include <random>
#include <cstdint>
#include <lib/shishua/utils.h>
#include <lib/shishua/shishua.h>
#include <lib/distribution/zipfian.h>

#define UNIFORM_BUFFER_CAPACITY 1024

namespace Distribution {

    template<typename DistributionTypeT>
    struct UniformDistribution {
        DistributionTypeT min;
        DistributionTypeT max;

        size_t current;
        prng_state shishua_prng;
        std::vector<DistributionTypeT> buffer;

        UniformDistribution() :
            min(std::numeric_limits<DistributionTypeT>::lowest()),
            max(std::numeric_limits<DistributionTypeT>::max()),
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
        std::mt19937 engine;
        zipfian_distribution<DistributionTypeT> distribution;

        explicit ZipfianDistribution()
            : engine(std::random_device{}()), distribution() {}

        explicit ZipfianDistribution(DistributionTypeT lower_bound, DistributionTypeT upper_bound, float skew)
            : engine(std::random_device{}()), distribution(lower_bound, upper_bound, skew) {}

        void setParams(DistributionTypeT min, DistributionTypeT max, float skew) {
            distribution.param(typename zipfian_distribution<DistributionTypeT>::param_type(min, max, skew));
        }

        DistributionTypeT nextValue() {
            return distribution(engine);
        }
    };
};

#endif