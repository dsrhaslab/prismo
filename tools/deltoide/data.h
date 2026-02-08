#ifndef DATA_H
#define DATA_H

#include <nlohmann/json.hpp>

using json = nlohmann::json;
using CompressionDB = std::map<uint32_t, uint64_t>;
using DuplicationDB = std::map<uint64_t, std::pair<uint64_t, CompressionDB>>;

namespace std {

    void to_json(json& j, const CompressionDB& db) {
        for (const auto& [compression, percentage] : db) {
            if (percentage > 0) {
                j.push_back({
                    {"reduction", compression},
                    {"percentage", percentage},
                });
            }
        }
    }

    void to_json(json& j, const DuplicationDB db) {
        for (const auto& [repeats, value] : db) {
            if (value.first > 0) {
                j.push_back({
                    {"repeats", repeats },
                    {"percentage", value.first},
                    {"compression", static_cast<json>(value.second)}
                });
            }
        }
    }
}

uint32_t shannon_entropy(const char* data, size_t length) {
    double entropy = 0.0;
    std::vector<uint64_t> freq(256, 0);

    for (size_t index = 0; index < length; index++) {
        uint8_t byte = static_cast<uint8_t>(data[index]);
        freq[byte]++;
    }

    for (size_t index = 0; index < 256; index++) {
        if (freq[index] != 0) {
            double prob =
                static_cast<double>(freq[index]) /
                static_cast<double>(length);
            entropy -= prob * std::log2(prob);
        }
    }

    constexpr double max_entropy = 8.0;
    double percent = (entropy / max_entropy) * 100.0;

    percent = std::clamp(percent, 0.0, 100.0);
    return static_cast<uint32_t>(std::round(percent));
}

void update_compression_db(uint32_t compression, CompressionDB& db) {
    db[compression]++;
}

void update_duplication_db(uint64_t header, uint32_t compression, DuplicationDB& db) {
    db[header].first++;
    db[header].second[compression]++;
}

#endif