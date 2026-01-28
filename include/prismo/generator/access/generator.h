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
            AccessGenerator() = default;

            virtual ~AccessGenerator() {
                std::cout << "~Destroying AccessGenerator" << std::endl;
            };

            virtual uint64_t next_offset(void) = 0;

            virtual void validate(void) const {
                if (block_size == 0) {
                    throw std::invalid_argument("access_validate: block_size must be greater than zero");
                } else if (block_size > limit) {
                    throw std::invalid_argument("access_validate: block_size must be less than or equal to limit");
                }
            };

            friend void from_json(const json& j, AccessGenerator& access_generator) {
                j.at("block_size").get_to(access_generator.block_size);
                j.at("limit").get_to(access_generator.limit);
            };
    };

    class SequentialAccessGenerator : public AccessGenerator {
        private:
            uint64_t current_offset;

        public:
            SequentialAccessGenerator() = default;

            ~SequentialAccessGenerator() override {
                std::cout << "~Destroying SequentialAccessGenerator" << std::endl;
            }

            uint64_t next_offset(void) override {
                const uint64_t offset = current_offset;
                current_offset = static_cast<uint64_t>((current_offset + block_size) % limit);
                return offset;
            };

            void validate(void) const {
                AccessGenerator::validate();
            };

            friend void from_json(const json& j, SequentialAccessGenerator& access_generator) {
                from_json(j, static_cast<AccessGenerator&>(access_generator));
                access_generator.validate();
                access_generator.limit =
                    access_generator.block_size *
                    (access_generator.limit / access_generator.block_size);
            };
    };

    class RandomAccessGenerator : public AccessGenerator {
        private:
            Distribution::UniformDistribution<uint64_t> distribution;

        public:
            RandomAccessGenerator() = default;

            ~RandomAccessGenerator() override {
                std::cout << "~Destroying RandomAccessGenerator" << std::endl;
            }

            uint64_t next_offset(void) override {
                return static_cast<uint64_t>(distribution.nextValue() * block_size);
            };

            void validate(void) const {
                AccessGenerator::validate();
            };

            friend void from_json(const json& j, RandomAccessGenerator& access_generator) {
                from_json(j, static_cast<AccessGenerator&>(access_generator));
                access_generator.validate();
                access_generator.limit = access_generator.limit / access_generator.block_size - 1;
                access_generator.distribution.setParams(0, access_generator.limit);
            };
    };

    class ZipfianAccessGenerator : public AccessGenerator {
        private:
            float skew;
            Distribution::ZipfianDistribution<uint64_t> distribution;

        public:
            ZipfianAccessGenerator()
                : AccessGenerator(), skew(0), distribution(0, 99, 0.9f) {};

            ~ZipfianAccessGenerator() override {
                std::cout << "~Destroying ZipfianAccessGenerator" << std::endl;
            };

            uint64_t next_offset(void) override {
                return static_cast<uint64_t>(distribution.nextValue() * block_size);
            };

            void validate(void) const {
                AccessGenerator::validate();
                if (skew <= 0 || skew >= 1) {
                    throw std::invalid_argument("zipfian_validate: skew must belong to range [0; 1]");
                }
            };

            friend void from_json(const json& j, ZipfianAccessGenerator& access_generator) {
                from_json(j, static_cast<AccessGenerator&>(access_generator));
                j.at("skew").get_to(access_generator.skew);
                access_generator.validate();

                access_generator.limit =
                    access_generator.limit /
                    access_generator.block_size - 1;

                access_generator.distribution.setParams(
                    0,
                    access_generator.limit,
                    access_generator.skew
                );
            };
    };
};

#endif