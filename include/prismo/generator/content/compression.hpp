#ifndef PRISMO_GENERATOR_CONTENT_COMPRESSION_H
#define PRISMO_GENERATOR_CONTENT_COMPRESSION_H

#include <vector>
#include <cstdint>
#include <iostream>
#include <nlohmann/json.hpp>
#include <prismo/generator/content/metadata.hpp>
#include <lib/distribution/distribution.hpp>

namespace Generator {

    struct CompressionGenerator {
        private:
            Distribution::DiscreteDistribution<uint32_t> distribution;

        public:
            CompressionGenerator() = default;

            ~CompressionGenerator();

            CompressionGenerator(const nlohmann::json& j);

            uint32_t apply(uint8_t* buffer, size_t size);
    };
}

#endif