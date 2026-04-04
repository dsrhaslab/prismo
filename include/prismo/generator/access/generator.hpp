#ifndef PRISMO_GENERATOR_ACCESS_GENERATOR_H
#define PRISMO_GENERATOR_ACCESS_GENERATOR_H

#include <cstddef>
#include <iostream>
#include <nlohmann/json.hpp>
#include <lib/distribution/distribution.hpp>

namespace Generator {

    class AccessGenerator {
        protected:
            size_t block_size;
            size_t partition_size;
            uint64_t partition_start;

            AccessGenerator() = delete;

            explicit AccessGenerator(const nlohmann::json& j);

        public:
            virtual ~AccessGenerator();

            virtual uint64_t next_offset(void) = 0;
    };

    class SequentialAccessGenerator : public AccessGenerator {
        private:
            uint64_t current_offset = 0;

        public:
            SequentialAccessGenerator() = delete;

            ~SequentialAccessGenerator() override;

            explicit SequentialAccessGenerator(const nlohmann::json& j);

            uint64_t next_offset(void) override;
    };

    class RandomAccessGenerator : public AccessGenerator {
        private:
            size_t normalized_partition_size = 0;
            Distribution::UniformDistribution<uint64_t> rng;

        public:
            RandomAccessGenerator() = delete;

            ~RandomAccessGenerator() override;

            explicit RandomAccessGenerator(const nlohmann::json& j);

            uint64_t next_offset(void) override;
    };

    class ZipfianAccessGenerator : public AccessGenerator {
        private:
            float skew = 0.0f;
            size_t normalized_partition_size = 0;
            Distribution::ZipfianDistribution<uint64_t> distribution;

        public:
            ZipfianAccessGenerator() = delete;

            ~ZipfianAccessGenerator() override;

            explicit ZipfianAccessGenerator(const nlohmann::json& j);

            uint64_t next_offset(void) override;
    };
};

#endif