#ifndef DATA_H
#define DATA_H

#include "zstdpp.hpp"
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

uint32_t zstd_compress(const std::vector<uint8_t>& data) {
    auto compressed = zstdpp::compress(data);
    size_t compressed_size = compressed.size();

    double reduction =
        100.0 * (1.0 -
            static_cast<double>(compressed_size) /
            static_cast<double>(data.size())
        );

    reduction = std::clamp(reduction, 0.0, 100.0);
    return static_cast<uint32_t>(std::round(reduction));
}

void update_compression_db(uint32_t compression, CompressionDB& db) {
    db[compression]++;
}

void update_duplication_db(uint64_t header, uint32_t compression, DuplicationDB& db) {
    db[header].first++;
    db[header].second[compression]++;
}

#endif