#ifndef SYNTHETIC_GENERATOR_H
#define SYNTHETIC_GENERATOR_H

#include <cstring>
#include <prismo/generator/metadata.h>
#include <lib/shishua/shishua.h>
#include <lib/shishua/utils.h>

namespace Generator {

    class Generator {
        protected:
            uint64_t block_id = 0;

        public:
            Generator() = default;

            virtual ~Generator() {
                // std::cout << "~Destroying Generator" << std::endl;
            }

            virtual BlockMetadata next_block(uint8_t* buffer, size_t size) = 0;
    };

    class ConstantGenerator : public Generator {
        public:
            ConstantGenerator() = default;

            ~ConstantGenerator() override {
                // std::cout << "~Destroying ConstantGenerator" << std::endl;
            }

            BlockMetadata next_block(uint8_t* buffer, size_t size) override {
                std::memset(buffer, 0, size);
                std::memcpy(buffer, &block_id, sizeof(block_id));
                return BlockMetadata {
                    .block_id = block_id++,
                    .compression = 100
                };
            }
    };

    class RandomGenerator : public Generator {
        private:
            prng_state generator;

        public:
            RandomGenerator() : Generator() {
                auto seed = generate_seed();
                prng_init(&generator, seed.data());
            };

            ~RandomGenerator() override {
                // std::cout << "~Destroying RandomGenerator" << std::endl;
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
