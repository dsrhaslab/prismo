#ifndef ACCESS_GENERATOR_H
#define ACCESS_GENERATOR_H

#include <cstddef>
#include <iostream>
#include <nlohmann/json.hpp>
#include <lib/distribution/distribution.h>

using json = nlohmann::json;

namespace Generator {

    class AccessGenerator {
        protected:
            size_t block_size;
            size_t limit;

        public:
            AccessGenerator() = delete;

            virtual ~AccessGenerator() {
                std::cout << "~Destroying AccessGenerator" << std::endl;
            };

            explicit AccessGenerator(const json& j) {
                block_size = j.at("block_size").get<size_t>();
                limit = j.at("limit").get<size_t>();
            }

            virtual uint64_t next_offset(void) = 0;

            virtual void validate(void) const {
                if (block_size == 0) {
                    throw std::invalid_argument("access_validate: block_size must be greater than zero");
                } else if (block_size > limit) {
                    throw std::invalid_argument("access_validate: block_size must be less than or equal to limit");
                }
            };
    };

    class SequentialAccessGenerator : public AccessGenerator {
        private:
            uint64_t current_offset;

        public:
            SequentialAccessGenerator() = delete;

            ~SequentialAccessGenerator() override {
                std::cout << "~Destroying SequentialAccessGenerator" << std::endl;
            }

            explicit SequentialAccessGenerator(const json& j)
                : AccessGenerator(j), current_offset(0)
            {
                limit = block_size * (limit / block_size);
            };

            uint64_t next_offset(void) override {
                const uint64_t offset = current_offset;
                current_offset = static_cast<uint64_t>((current_offset + block_size) % limit);
                return offset;
            };

            void validate(void) const override {
                AccessGenerator::validate();
            };
    };

    class RandomAccessGenerator : public AccessGenerator {
        private:
            size_t normalized_limit;
            Distribution::UniformDistribution<uint64_t> rng;

        public:
            RandomAccessGenerator() = delete;

            ~RandomAccessGenerator() override {
                std::cout << "~Destroying RandomAccessGenerator" << std::endl;
            }

            explicit RandomAccessGenerator(const json& j)
                : AccessGenerator(j), normalized_limit(0), rng()
            {
                normalized_limit = limit / block_size - 1;
                rng.setParams(0, normalized_limit);
            };

            uint64_t next_offset(void) override {
                return static_cast<uint64_t>(rng.nextValue() * block_size);
            };

            void validate(void) const override {
                AccessGenerator::validate();
            };
    };

    class ZipfianAccessGenerator : public AccessGenerator {
        private:
            float skew;
            size_t normalized_limit;
            Distribution::ZipfianDistribution<uint64_t> distribution;

        public:
            ZipfianAccessGenerator() = delete;

            ~ZipfianAccessGenerator() override {
                std::cout << "~Destroying ZipfianAccessGenerator" << std::endl;
            };

            explicit ZipfianAccessGenerator(const json& j)
                : AccessGenerator(j), skew(0.0f), normalized_limit(0), distribution()
            {
                normalized_limit = limit / block_size - 1;
                distribution.setParams(0, normalized_limit, skew);
            };

            uint64_t next_offset(void) override {
                return static_cast<uint64_t>(distribution.nextValue() * block_size);
            };

            void validate(void) const override {
                AccessGenerator::validate();
                if (skew <= 0 || skew >= 1) {
                    throw std::invalid_argument("zipfian_validate: skew must belong to range [0; 1]");
                }
            };
    };
};

#endif