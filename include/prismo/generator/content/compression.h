#ifndef COMPRESSION_GENERATOR_H
#define COMPRESSION_GENERATOR_H

#include <vector>
#include <cstdint>
#include <iostream>
#include <nlohmann/json.hpp>
#include <prismo/generator/content/metadata.h>
#include <lib/distribution/distribution.h>

using json = nlohmann::json;

namespace Generator {

    struct CompressionGenerator {
        private:
            Distribution::DiscreteDistribution<uint32_t> distribution;

        public:
            CompressionGenerator() = default;

            ~CompressionGenerator() {
                std::cout << "~Destroying CompressionGenerator" << std::endl;
            };

            CompressionGenerator(const json& j)
                : distribution([&] {
                    std::vector<uint32_t> values, weights;
                    for (const auto& item : j) {
                        values.push_back(item.at("reduction").get<uint32_t>());
                        weights.push_back(item.at("percentage").get<uint32_t>());
                    }
                    return Distribution::DiscreteDistribution<uint32_t>(
                        "compression_generator", values, weights);
                }())
            {}

            uint32_t apply(uint8_t* buffer, size_t size) {
                uint32_t compression = distribution.nextValue();
                size_t compressed_size = (size - sizeof(BlockMetadata::block_id)) * compression / 100;
                std::memset(buffer + sizeof(BlockMetadata::block_id), 0, compressed_size);
                return compression;
            }
    };
}

#endif