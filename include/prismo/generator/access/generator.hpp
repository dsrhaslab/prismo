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
            size_t limit;

            AccessGenerator() = delete;

            explicit AccessGenerator(const nlohmann::json& j) {
                block_size = j.at("block_size").get<size_t>();
                limit = j.at("limit").get<size_t>();

                if (block_size == 0) {
                    throw std::invalid_argument("AccessGenerator: block_size must be greater than zero");
                } else if (block_size > limit) {
                    throw std::invalid_argument("AccessGenerator: block_size must be less than or equal to limit");
                }
            }

        public:
            virtual ~AccessGenerator() {
                std::cout << "~Destroying AccessGenerator" << std::endl;
            };

            virtual uint64_t next_offset(void) = 0;
    };

    class SequentialAccessGenerator : public AccessGenerator {
        private:
            uint64_t current_offset = 0;

        public:
            SequentialAccessGenerator() = delete;

            ~SequentialAccessGenerator() override {
                std::cout << "~Destroying SequentialAccessGenerator" << std::endl;
            }

            explicit SequentialAccessGenerator(const nlohmann::json& j) : AccessGenerator(j) {
                limit = block_size * (limit / block_size);
            };

            uint64_t next_offset(void) override {
                const uint64_t offset = current_offset;
                current_offset = static_cast<uint64_t>((current_offset + block_size) % limit);
                return offset;
            };
    };

    class RandomAccessGenerator : public AccessGenerator {
        private:
            size_t normalized_limit = 0;
            Distribution::UniformDistribution<uint64_t> rng;

        public:
            RandomAccessGenerator() = delete;

            ~RandomAccessGenerator() override {
                std::cout << "~Destroying RandomAccessGenerator" << std::endl;
            }

            explicit RandomAccessGenerator(const nlohmann::json& j) : AccessGenerator(j) {
                normalized_limit = limit / block_size - 1;
                rng.setParams(0, normalized_limit);
            };

            uint64_t next_offset(void) override {
                return static_cast<uint64_t>(rng.nextValue() * block_size);
            };
    };

    class ZipfianAccessGenerator : public AccessGenerator {
        private:
            float skew = 0.0f;
            size_t normalized_limit = 0;
            Distribution::ZipfianDistribution<uint64_t> distribution;

        public:
            ZipfianAccessGenerator() = delete;

            ~ZipfianAccessGenerator() override {
                std::cout << "~Destroying ZipfianAccessGenerator" << std::endl;
            };

            explicit ZipfianAccessGenerator(const nlohmann::json& j) : AccessGenerator(j) {
                skew = j.at("skew").get<float>();

                if (skew <= 0 || skew >= 1) {
                    throw std::invalid_argument("ZipfianAccessGenerator: skew must belong to range [0; 1]");
                }

                normalized_limit = limit / block_size - 1;
                distribution.setParams(0, normalized_limit, skew);
            };

            uint64_t next_offset(void) override {
                return static_cast<uint64_t>(distribution.nextValue() * block_size);
            };
    };
};

#endif