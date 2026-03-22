#ifndef LIB_DISTRIBUTION_PERCENTILE_H
#define LIB_DISTRIBUTION_PERCENTILE_H

#include <vector>
#include <cmath>
#include <cstdint>
#include <algorithm>
#include <bit>
#include <cassert>

namespace Percentile {

    class HDR {
        private:
            int significant_digits_;
            int sub_bucket_half_count_magnitude_;
            int sub_bucket_count_;
            int sub_bucket_half_count_;
            uint64_t sub_bucket_mask_;
            int unit_magnitude_;
            int bucket_count_;
            int counts_len_;

            std::vector<uint64_t> counts_;
            uint64_t total_count_ = 0;
            uint64_t min_value_ = UINT64_MAX;
            uint64_t max_value_ = 0;

            int get_bucket_index(uint64_t value) const {
                int pow2ceiling = 64 - std::countl_zero(value | sub_bucket_mask_);
                return std::max(0, pow2ceiling - unit_magnitude_ - (sub_bucket_half_count_magnitude_ + 1));
            }

            int get_sub_bucket_index(uint64_t value, int bucket_idx) const {
                return static_cast<int>(value >> (bucket_idx + unit_magnitude_));
            }

            int counts_index_for(uint64_t value) const {
                int bi = get_bucket_index(value);
                int si = get_sub_bucket_index(value, bi);
                return bi * sub_bucket_half_count_ + si;
            }

            void index_to_bucket_sub(int index, int& bucket_idx, int& sub_bucket_idx) const {
                if (index < sub_bucket_count_) {
                    bucket_idx = 0;
                    sub_bucket_idx = index;
                } else {
                    int adjusted = index - sub_bucket_half_count_;
                    bucket_idx = adjusted / sub_bucket_half_count_;
                    sub_bucket_idx = sub_bucket_half_count_ + adjusted % sub_bucket_half_count_;
                }
            }

            uint64_t value_from_bucket_sub(int bucket_idx, int sub_bucket_idx) const {
                return static_cast<uint64_t>(sub_bucket_idx) << (bucket_idx + unit_magnitude_);
            }

            uint64_t highest_equivalent_value(uint64_t value) const {
                int bi = get_bucket_index(value);
                int si = get_sub_bucket_index(value, bi);
                uint64_t lowest = value_from_bucket_sub(bi, si);
                int shift = unit_magnitude_ + bi;
                if (shift >= 64) return UINT64_MAX;
                uint64_t range = UINT64_C(1) << shift;
                return lowest + range - 1;
            }

            static int buckets_needed(uint64_t highest, int sub_bucket_count, int unit_magnitude) {
                uint64_t smallest_untrackable =
                    static_cast<uint64_t>(sub_bucket_count) << unit_magnitude;
                int buckets = 1;
                while (smallest_untrackable <= highest) {
                    if (smallest_untrackable > UINT64_MAX / 2) break;
                    smallest_untrackable <<= 1;
                    buckets++;
                }
                return buckets;
            }

        public:
            explicit HDR(
                int _significant_digits = 3,
                uint64_t _lowest_discernible_value = 1,
                uint64_t _highest_trackable_value = UINT64_C(3600000000000)
            ) : significant_digits_(_significant_digits)
            {
                int64_t largest = 2 * static_cast<int64_t>(
                    std::pow(10.0, _significant_digits));
                int sub_bucket_count_magnitude = static_cast<int>(
                    std::ceil(std::log(static_cast<double>(largest)) / std::log(2.0)));

                sub_bucket_half_count_magnitude_ =
                    ((sub_bucket_count_magnitude > 1) ? sub_bucket_count_magnitude : 1) - 1;

                unit_magnitude_ = static_cast<int>(std::floor(
                    std::log(static_cast<double>(
                        std::max(_lowest_discernible_value, UINT64_C(1)))) / std::log(2.0)));

                sub_bucket_count_ = 1 << (sub_bucket_half_count_magnitude_ + 1);
                sub_bucket_half_count_ = sub_bucket_count_ / 2;
                sub_bucket_mask_ =
                    static_cast<uint64_t>(sub_bucket_count_ - 1) << unit_magnitude_;

                bucket_count_ = buckets_needed(
                    _highest_trackable_value, sub_bucket_count_, unit_magnitude_);

                counts_len_ = (bucket_count_ + 1) * sub_bucket_half_count_;
                counts_.resize(counts_len_, 0);
            }

            void record(uint64_t value) {
                int idx = counts_index_for(value);
                if (idx < 0 || idx >= counts_len_) return;

                counts_[idx]++;
                total_count_++;
                min_value_ = std::min(min_value_, value);
                max_value_ = std::max(max_value_, value);
            }

            void merge(const HDR& other) {
                assert(significant_digits_ == other.significant_digits_
                    && unit_magnitude_ == other.unit_magnitude_
                    && "merging HDR histograms with different configurations");

                size_t common = std::min(
                    static_cast<size_t>(counts_len_),
                    static_cast<size_t>(other.counts_len_));
                for (size_t i = 0; i < common; i++) {
                    counts_[i] += other.counts_[i];
                }
                total_count_ += other.total_count_;
                min_value_ = std::min(min_value_, other.min_value_);
                max_value_ = std::max(max_value_, other.max_value_);
            }

            uint64_t get_percentile(double percentile) const {
                if (total_count_ == 0)
                    return 0;
                if (percentile <= 0.0)
                    return min_value_;
                if (percentile >= 100.0)
                    return max_value_;

                uint64_t target = static_cast<uint64_t>(
                    std::ceil(percentile * total_count_ / 100.0));

                uint64_t cumulative = 0;
                for (int i = 0; i < counts_len_; i++) {
                    cumulative += counts_[i];
                    if (cumulative >= target) {
                        int bi, si;
                        index_to_bucket_sub(i, bi, si);
                        uint64_t value = value_from_bucket_sub(bi, si);
                        return std::min(highest_equivalent_value(value), max_value_);
                    }
                }

                return max_value_;
            }
    };
}

#endif
