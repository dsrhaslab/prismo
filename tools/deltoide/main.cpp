#include <cmath>
#include <vector>
#include <fstream>
#include <iostream>
#include <filesystem>
#include <argparse/argparse.hpp>
#include <lib/komihash/komihash.h>
#include <nlohmann/json.hpp>

namespace fs = std::filesystem;

using json = nlohmann::json;
using CompressionDB = std::map<uint32_t, uint64_t>;
using DeduplicationDB = std::map<uint64_t, std::pair<uint64_t, CompressionDB>>;


namespace std {
    void to_json(json& j, const CompressionDB& db) {
        uint64_t total = 0;
        for (const auto& kv : db) {
            total += kv.second;
        }

        for (const auto& [compression, count] : db) {
            double reduction = static_cast<double>(count) / total * 100.0;
            std::cout << reduction << std::endl;
            reduction = std::clamp(reduction, 0.0, 100.0);
            j.push_back({
                {"compression", compression},
                {"reduction", static_cast<uint32_t>(std::round(reduction))}
            });
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


void update_dbs(
    const char* data,
    size_t length,
    DeduplicationDB& deduplication_db,
    CompressionDB& compression_db
) {

    uint32_t compression = shannon_entropy(data, length);
    std::cout << compression << std::endl;
    uint64_t dedup_header = komihash(data, length, 0);
    compression_db[compression]++;
    deduplication_db[dedup_header].first++;
    deduplication_db[dedup_header].second[compression]++;
}


int main(int argc, char** argv) {
    argparse::ArgumentParser program("deltoid");

    program.add_description("Generator distributions from dataset");

    program.add_argument("-i", "--input")
        .required()
        .help("specify the dataset directory");

    program.add_argument("-b", "--block-size")
        .default_value(static_cast<uint32_t>(4096))
        .help("specify the block size");

    try {
        program.parse_args(argc, argv);
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << program;
        return 1;
    }

    std::string dataset = program.get<std::string>("--input");
    uint32_t block_size = program.get<uint32_t>("--block-size");

    if (block_size <= sizeof(uint64_t)) {}

    CompressionDB compression_db;
    DeduplicationDB deduplication_db;

    fs::path dataset_path = dataset;
    std::vector<char> buffer(block_size);

    if (!fs::exists(dataset_path) || !fs::is_directory(dataset_path)) {
        std::cerr << "Invalid dataset directory: " << dataset << std::endl;
        return 1;
    }

    for (const fs::directory_entry& entry : fs::recursive_directory_iterator(dataset_path)) {
        if (!fs::is_regular_file(entry)) {
            continue;
        }

        std::ifstream file(entry.path(), std::ios::binary);
        if (!file || !file.is_open()) {
            std::cerr << "Error while opening: " << entry.path() << std::endl;
            continue;
        }

        std::cout << entry.path() << std::endl;

        while (file.read(buffer.data(), static_cast<std::streamsize>(sizeof(char) * buffer.capacity()))){
            const size_t bytes_read = static_cast<size_t>(file.gcount());
            update_dbs(buffer.data(), bytes_read, deduplication_db, compression_db);
        }

        if (file.gcount() > 0) {
            const size_t bytes_read = static_cast<size_t>(file.gcount());
            std::memset(buffer.data() + bytes_read, 0, block_size - bytes_read);
            update_dbs(buffer.data(), bytes_read, deduplication_db, compression_db);
        }

        file.close();
    }

    json compression_j = compression_db;
    std::cout << compression_j.dump(4) << std::endl;

    return 0;
}