#ifndef COMMON_PERCENTILE_H
#define COMMON_PERCENTILE_H

#include <bit>
#include <array>
#include <cmath>
#include <cstdint>
#include <algorithm>

namespace Percentile {

    class Calculator {
       private:
        static constexpr int NUM_BUCKETS = 64;
        std::array<uint64_t, NUM_BUCKETS> buckets = {};
        uint64_t total_count = 0;
        uint64_t min_value = UINT64_MAX;
        uint64_t max_value = 0;

        int get_bucket_index(uint64_t value) const {
            if (value == 0)
                return 0;
            int msb = std::bit_width(value) - 1;
            return std::min(msb, NUM_BUCKETS - 1);
        }

       public:
        Calculator() = default;

        void record(uint64_t value) {
            total_count++;
            min_value = std::min(min_value, value);
            max_value = std::max(max_value, value);

            int bucket = get_bucket_index(value);
            buckets[bucket]++;
        }

        uint64_t get_percentile(double percentile) const {
            if (total_count == 0)
                return 0;
            if (percentile <= 0.0)
                return min_value;
            if (percentile >= 100.0)
                return max_value;

            uint64_t target_count = static_cast<uint64_t>(
                std::ceil(percentile * total_count / 100.0));

            uint64_t cumulative = 0;
            for (int i = 0; i < NUM_BUCKETS; i++) {
                cumulative += buckets[i];
                if (cumulative >= target_count) {
                    return 1ULL << i;
                }
            }

            return max_value;
        }
    };
}

#endif
