#ifndef COMPRESSION_GENERATOR_H
#define COMPRESSION_GENERATOR_H

#include <vector>
#include <cstdint>
#include <iostream>
#include <nlohmann/json.hpp>
#include <prismo/generator/content/metadata.h>
#include <lib/distribution/percentage.h>
#include <lib/distribution/distribution.h>

using json = nlohmann::json;

namespace Generator {

    struct CompressionGenerator {
        private:
            Distribution::UniformDistribution<uint32_t> rng;
            std::vector<PercentageElement<uint32_t, uint32_t>> distribution;

        public:
            CompressionGenerator() = default;

            ~CompressionGenerator() {
                std::cout << "~Destroying CompressionGenerator" << std::endl;
            };

            explicit CompressionGenerator(const json& j) : rng(0,99) {
                uint32_t cumulative = 0;
                for (const auto& item : j) {
                    cumulative += item.at("percentage").get<uint32_t>();
                    distribution.push_back(PercentageElement<uint32_t, uint32_t> {
                        .cumulative_percentage = cumulative,
                        .value = item.at("reduction").get<uint32_t>(),
                    });
                }
            };

            uint32_t select_compression(void) {
                return select_from_percentage_vector(rng.nextValue(), distribution);
            }

            uint32_t apply(uint8_t* buffer, size_t size) {
                uint32_t compression = select_compression();
                size_t compressed_size = (size - sizeof(BlockMetadata::block_id)) * compression / 100;
                std::memset(buffer + sizeof(BlockMetadata::block_id), 0, compressed_size);
                return compression;
            }

            void validate(void) const {
                validate_percentage_vector(distribution, "compression");
            };
    };
}

#endif