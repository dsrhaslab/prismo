#ifndef DEDUPLICATION_CONTENT_GENERATOR_H
#define DEDUPLICATION_CONTENT_GENERATOR_H

#include <boost/pool/pool.hpp>
#include <prismo/generator/content/generator.h>
#include <prismo/generator/content/compression.h>
#include <lib/distribution/percentage.h>
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
            bool refill;
            size_t block_size;

            boost::pool<> pool;
            std::unique_ptr<uint8_t[]> refill_buffer;

            RandomContentGenerator random_generator;
            Distribution::UniformDistribution<uint32_t> distribution;

            std::unordered_map<uint32_t, std::vector<DedupElement>> dedup_windows;
            std::vector<PercentageElement<uint32_t, uint32_t>> dedup_percentages;
            std::unordered_map<uint32_t, CompressionGenerator> compression_generators;

            DedupElement reuse_dedup_element(uint32_t repeats, uint8_t* buffer, size_t size);
            DedupElement create_dedup_element(uint32_t repeats, uint32_t compression, size_t size);

        public:
            DeduplicationContentGenerator() = delete;

            explicit DeduplicationContentGenerator(const json& j);

            ~DeduplicationContentGenerator() override {
                std::cout << "~Destroying DeduplicationContentGenerator" << std::endl;
            }

            BlockMetadata next_block(uint8_t* buffer, size_t size) override;

            void validate(void) const override {
                validate_percentage_vector(dedup_percentages, "deduplication");
                for (const auto& [_, generator] : compression_generators) {
                    generator.validate();
                }
            };
    };
}

#endif