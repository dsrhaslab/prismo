#ifndef NORMALIZER_H
#define NORMALIZER_H

#include <data.h>
#include <iostream>

std::vector<uint64_t> largest_remainder(const std::vector<double>& values) {
    if (values.empty()) {
        return {};
    }

    int floor_sum = 0;
    size_t n = values.size();

    std::vector<uint64_t> result(n);
    std::vector<double> fractions(n);

    for (size_t idx = 0; idx < n; idx++) {
        result[idx] = static_cast<uint64_t>(values[idx]);
        fractions[idx] = values[idx] - static_cast<double>(result[idx]);
        floor_sum += static_cast<int>(result[idx]);
    }

    int to_distribute = 100 - floor_sum;

    if (to_distribute <= 0) {
        return result;
    }

    std::vector<size_t> indices(n);
    for (size_t idx = 0; idx < n; idx++) {
        indices[idx] = idx;
    }

    std::stable_sort(indices.begin(), indices.end(),
        [&](size_t a, size_t b) {
            return fractions[a] > fractions[b];
        });

    for (int i = 0; i < to_distribute; i++) {
        size_t idx = indices[static_cast<size_t>(i)];
        result[idx]++;
    }

    return result;
}

void normalize(CompressionDB& db) {
    uint64_t total = 0;
    std::vector<double> percentages;

    for (const auto& [_, count] : db) {
        total += count;
    }

    for (auto& kv : db) {
        percentages.push_back(
            static_cast<double>(kv.second) /
            static_cast<double>(total) * 100.0
        );
    }

    auto it = db.begin();
    std::vector<uint64_t> normalized = largest_remainder(percentages);

    for (auto& value : normalized) {
        it->second = value;
        ++it;
    }
}

void normalize(DuplicationDB& db) {
    uint64_t total = 0;
    DuplicationDB result_db;
    std::vector<double> percentages;

    for (const auto& [hash, value] : db) {
        result_db[value.first - 1].first++;
        for (const auto& [compression, count] : value.second) {
            result_db[value.first - 1].second[compression] += count;
        }
    }

    for (auto& [repeats, value] : result_db) {
        total += value.first * (repeats + 1);
        normalize(value.second);
    }

    for (const auto& [repeats, value] : result_db) {
        percentages.push_back(
            static_cast<double>(value.first * (repeats + 1)) /
            static_cast<double>(total) * 100.0
        );
    }

    auto it = result_db.begin();
    std::vector<uint64_t> normalized = largest_remainder(percentages);

    for (auto& value : normalized) {
        it->second.first = value;
        ++it;
    }

    db = result_db;
}


#endif
