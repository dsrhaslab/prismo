#ifndef CONTENT_GENERATOR_H
#define CONTENT_GENERATOR_H

#include <cstring>
#include <iostream>
#include <nlohmann/json.hpp>
#include <prismo/generator/content/metadata.h>
#include <lib/distribution/distribution.h>
#include <lib/shishua/shishua.h>
#include <lib/shishua/utils.h>

namespace Generator {

    class ContentGenerator {
        private:
            bool refill_flag;
            prng_state shishua_prng;
            std::vector<uint8_t> base_buffer;

        protected:
            uint64_t block_id = 0;

            ContentGenerator() = delete;

            explicit ContentGenerator(const nlohmann::json& j)
                : ContentGenerator(j, j.at("refill").get<bool>()) {}

            explicit ContentGenerator(const nlohmann::json& j, bool _refill_flag)
                :
                refill_flag(_refill_flag),
                base_buffer(j.at("block_size").get<size_t>())
            {
                prng_init(&shishua_prng, generate_seed().data());
                prng_gen(&shishua_prng, base_buffer.data(), base_buffer.size());
            }

            void refill(uint8_t* buffer, size_t size) {
                if (refill_flag) {
                    prng_gen(&shishua_prng, buffer, size);
                } else {
                    std::memcpy(buffer, base_buffer.data(), size);
                }
            }

        public:
            virtual ~ContentGenerator() {
                std::cout << "~Destroying ContentGenerator" << std::endl;
            }

            virtual BlockMetadata next_block(uint8_t* buffer, size_t size) = 0;
    };

    class ConstantContentGenerator : public ContentGenerator {
        public:
            ConstantContentGenerator() = delete;

            ~ConstantContentGenerator() override {
                std::cout << "~Destroying ConstantContentGenerator" << std::endl;
            }

            explicit ConstantContentGenerator(const nlohmann::json& j)
                : ContentGenerator(j, false) {}

            BlockMetadata next_block(uint8_t* buffer, size_t size) override {
                refill(buffer, size);
                std::memcpy(buffer, &block_id, sizeof(block_id));
                return BlockMetadata {
                    .block_id = block_id,
                    .compression = 0
                };
            }
    };

    class RandomContentGenerator : public ContentGenerator {
        private:
            Distribution::UniformDistribution<uint64_t> rng;

        public:
            RandomContentGenerator() = delete;

            ~RandomContentGenerator() override {
                std::cout << "~Destroying RandomContentGenerator" << std::endl;
            }

            explicit RandomContentGenerator(const nlohmann::json& j)
                : ContentGenerator(j) {}

            BlockMetadata next_block(uint8_t* buffer, size_t size) override {
                refill(buffer, size);
                block_id = rng.nextValue();
                std::memcpy(buffer, &block_id, sizeof(block_id));
                return BlockMetadata {
                    .block_id = block_id,
                    .compression = 0
                };
            }
    };
}

#endif
