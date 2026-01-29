#ifndef CONTENT_GENERATOR_H
#define CONTENT_GENERATOR_H

#include <cstring>
#include <iostream>
#include <prismo/generator/content/metadata.h>
#include <lib/shishua/shishua.h>
#include <lib/shishua/utils.h>

namespace Generator {

    class ContentGenerator {
        protected:
            uint64_t block_id = 0;

        public:
            ContentGenerator() = default;

            virtual ~ContentGenerator() {
                std::cout << "~Destroying ContentGenerator" << std::endl;
            }

            virtual BlockMetadata next_block(uint8_t* buffer, size_t size) = 0;
    };

    class ConstantContentGenerator : public ContentGenerator {
        public:
            ConstantContentGenerator() = default;

            ~ConstantContentGenerator() override {
                std::cout << "~Destroying ConstantContentGenerator" << std::endl;
            }

            BlockMetadata next_block(uint8_t* buffer, size_t size) override {
                std::memset(buffer, 0, size);
                std::memcpy(buffer, &block_id, sizeof(block_id));
                return BlockMetadata {
                    .block_id = block_id,
                    .compression = 100
                };
            }
    };

    class RandomContentGenerator : public ContentGenerator {
        private:
            prng_state generator;

        public:
            RandomContentGenerator() : ContentGenerator() {
                auto seed = generate_seed();
                prng_init(&generator, seed.data());
            };

            ~RandomContentGenerator() override {
                std::cout << "~Destroying RandomContentGenerator" << std::endl;
            }

            BlockMetadata next_block(uint8_t* buffer, size_t size) {
                prng_gen(&generator, buffer, size);
                std::memcpy(buffer, &block_id, sizeof(block_id));
                return BlockMetadata {
                    .block_id = block_id++,
                    .compression = 0
                };
            }
    };
}

#endif
