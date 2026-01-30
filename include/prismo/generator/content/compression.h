#ifndef COMPRESSION_GENERATOR_H
#define COMPRESSION_GENERATOR_H

#include <vector>
#include <cstdint>
#include <nlohmann/json.hpp>
#include <lib/distribution/percentage.h>

using json = nlohmann::json;

namespace Generator {

    inline void apply_compression(uint8_t* buffer, size_t size, uint32_t compression) {
        size_t compressed_size = size * compression / 100;
        std::memset(buffer, 0, compressed_size);
    };

    struct CompressionGenerator {
        private:
            std::vector<PercentageElement<uint32_t, uint32_t>> distribution;

        public:
            CompressionGenerator() = default;

            ~CompressionGenerator() {
                std::cout << "~Destroying CompressionGenerator" << std::endl;
            };

            explicit CompressionGenerator(const json& j) : distribution() {
                uint32_t cumulative = 0;
                for (const auto& item : j) {
                    cumulative += item.at("percentage").get<uint32_t>();
                    distribution.push_back(PercentageElement<uint32_t, uint32_t> {
                        .cumulative_percentage = cumulative,
                        .value = item.at("reduction").get<uint32_t>(),
                    });
                }
            };

            uint32_t select_compression(uint32_t roll) {
                return select_from_percentage_vector(roll, distribution);
            };

            void validate(void) const {
                validate_percentage_vector(distribution, "compression");
            };
    };
}

#endif