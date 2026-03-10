#ifndef DELTOIDE_DATA_H
#define DELTOIDE_DATA_H

#include <lib/zstd/zstdpp.hpp>
#include <nlohmann/json.hpp>
#include <common/metadata.hpp>

using CompressionDB = std::unordered_map<uint32_t, uint64_t>;
using DuplicationDB = std::unordered_map<uint64_t, std::pair<uint64_t, CompressionDB>>;

namespace std {
    void to_json(nlohmann::json& j, const CompressionDB& db) {
        for (const auto& [compression, percentage] : db) {
            if (percentage > 0) {
                j.push_back({
                    {"reduction", compression},
                    {"percentage", percentage},
                });
            }
        }
    }

    void to_json(nlohmann::json& j, const DuplicationDB db) {
        for (const auto& [repeats, value] : db) {
            if (value.first > 0) {
                j.push_back({
                    {"repeats", repeats },
                    {"percentage", value.first},
                    {"compression", static_cast<nlohmann::json>(value.second)}
                });
            }
        }
    }
}

uint32_t zstd_compress(const std::vector<uint8_t>& data) {
    std::vector<uint8_t> sliced(
        data.begin() + sizeof(Common::BlockMetadata::block_id),
        data.end()
    );

    auto compressed = zstdpp::compress(sliced);
    size_t compressed_size = compressed.size();

    double reduction =
        100.0 * (1.0 -
            static_cast<double>(compressed_size) /
            static_cast<double>(sliced.size())
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