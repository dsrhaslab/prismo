#ifndef DEDUPLICATION_CONTENT_GENERATOR_H
#define DEDUPLICATION_CONTENT_GENERATOR_H

#include <boost/pool/pool.hpp>
#include <prismo/generator/content/generator.h>
#include <prismo/generator/content/compression.h>
#include <lib/distribution/distribution.h>

#define DEDUP_WINDOW_SIZE 5

namespace Generator {

    struct DedupElement {
        uint64_t block_id;
        uint32_t left_repeats;
        uint32_t compression;
        uint8_t* buffer;
    };

    class DeduplicationContentGenerator : public ContentGenerator {
        private:
            boost::pool<> pool;

            std::unordered_map<uint32_t, CompressionGenerator> compression_generators;
            std::unordered_map<uint32_t, std::vector<DedupElement>> dedup_windows;

            Distribution::UniformDistribution<uint32_t> rng;
            Distribution::DiscreteDistribution<uint32_t> dedup_distribution;

            DedupElement create_dedup_element(uint32_t repeats, uint8_t* buffer, size_t size);
            DedupElement reuse_dedup_element(uint32_t repeats, uint8_t* buffer, size_t size);

        public:
            DeduplicationContentGenerator() = delete;

            explicit DeduplicationContentGenerator(const json& j);

            ~DeduplicationContentGenerator() override {
                std::cout << "~Destroying DeduplicationContentGenerator" << std::endl;
            }

            BlockMetadata next_block(uint8_t* buffer, size_t size) override;

            void validate(void) const override {
                // validate_percentage_vector(dedup_percentages, "deduplication");
                // for (const auto& [_, generator] : compression_generators) {
                //     generator.validate();
                // }
            };
    };
}

#endif