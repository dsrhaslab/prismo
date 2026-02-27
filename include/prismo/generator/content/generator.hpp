#ifndef PRISMO_GENERATOR_CONTENT_GENERATOR_H
#define PRISMO_GENERATOR_CONTENT_GENERATOR_H

#include <cstring>
#include <iostream>
#include <nlohmann/json.hpp>
#include <prismo/generator/content/metadata.hpp>
#include <lib/distribution/distribution.hpp>
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

            explicit ContentGenerator(const nlohmann::json& j);

            explicit ContentGenerator(const nlohmann::json& j, bool _refill_flag);

            void refill(uint8_t* buffer, size_t size);

        public:
            virtual ~ContentGenerator();

            virtual BlockMetadata next_block(uint8_t* buffer, size_t size) = 0;
    };

    class ConstantContentGenerator : public ContentGenerator {
        public:
            ConstantContentGenerator() = delete;

            ~ConstantContentGenerator() override;

            explicit ConstantContentGenerator(const nlohmann::json& j);

            BlockMetadata next_block(uint8_t* buffer, size_t size) override;
    };

    class RandomContentGenerator : public ContentGenerator {
        private:
            Distribution::UniformDistribution<uint64_t> rng;

        public:
            RandomContentGenerator() = delete;

            ~RandomContentGenerator() override;

            explicit RandomContentGenerator(const nlohmann::json& j);

            BlockMetadata next_block(uint8_t* buffer, size_t size) override;
    };
}

#endif
