#ifndef DEDUPLICATION_GENERATOR_H
#define DEDUPLICATION_GENERATOR_H

#include <boost/pool/pool.hpp>
#include <generator/synthetic.h>
#include <generator/compression.h>
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

    struct DeduplicationGeneratorConfig {
        private:
            bool refill_buffers;
            size_t block_size;
            std::vector<PercentageElement<uint32_t, uint32_t>> dedup_percentages;
            std::unordered_map<uint32_t, CompressionGenerator> compression_generators;

        public:
            bool get_refill_buffers(void) const {
                return refill_buffers;
            };

            size_t get_block_size(void) const {
                return block_size;
            };

            void add_dedup_percentage(
                PercentageElement<uint32_t, uint32_t> dedup_percentage
            ) {
                dedup_percentages.push_back(dedup_percentage);
            };

            void add_compression_generator(
                uint32_t repeats,
                CompressionGenerator compression_generator
            ) {
                compression_generators[repeats] = compression_generator;
            };

            uint32_t select_repeats(uint32_t roll) {
                return select_from_percentage_vector(roll, dedup_percentages);
            };

            uint32_t select_compression(uint32_t roll, uint32_t repeats) {
                return compression_generators[repeats].select_compression(roll);
            };

            void validate(void) const {
                validate_percentage_vector(dedup_percentages, "deduplication");
                for (const auto& [_, generator] : compression_generators) {
                    generator.validate();
                }
            };

            friend inline void from_json(const json& j, DeduplicationGeneratorConfig& config) {
                uint32_t cumulative_deduplication = 0;

                j.at("block_size").get_to(config.block_size);
                j.at("refill_buffers").get_to(config.refill_buffers);

                for (const auto& dedup_item : j.at("distribution")) {
                    uint32_t repeats = dedup_item.at("repeats").get<uint32_t>();
                    cumulative_deduplication += dedup_item.at("percentage").get<uint32_t>();

                    config.add_dedup_percentage(
                        PercentageElement<uint32_t, uint32_t> {
                            .cumulative_percentage = cumulative_deduplication,
                            .value = repeats,
                    });

                    CompressionGenerator compression_generator = dedup_item.get<CompressionGenerator>();
                    config.add_compression_generator(repeats, compression_generator);
                }

                config.validate();
            }
    };

    class DeduplicationGenerator : public Generator {
        private:
            boost::pool<> pool;
            std::unique_ptr<uint8_t[]> refill_buffer;

            RandomGenerator random_generator;
            DeduplicationGeneratorConfig config;

            Distribution::UniformDistribution<uint32_t> distribution;
            std::unordered_map<uint32_t, std::vector<DedupElement>> dedup_windows;

            DedupElement reuse_dedup_element(uint32_t repeats, uint8_t* buffer, size_t size);
            DedupElement create_dedup_element(uint32_t repeats, uint32_t compression, size_t size);

        public:
            DeduplicationGenerator() = delete;
            DeduplicationGenerator(const DeduplicationGeneratorConfig& _config);

            ~DeduplicationGenerator() override {
                // std::cout << "~Destroying DeduplicationGenerator" << std::endl;
            }

            BlockMetadata next_block(uint8_t* buffer, size_t size) override;
    };
}

#endif