#ifndef SYNTHETIC_ACCESS_H
#define SYNTHETIC_ACCESS_H

#include <cstddef>
#include <iostream>
#include <stdexcept>
#include <nlohmann/json.hpp>
#include <lib/distribution/distribution.h>

using json = nlohmann::json;

namespace Access {

    class Access {
        protected:
            size_t block_size;
            size_t limit;

        public:
            Access() = default;
            Access(size_t _block_size, size_t _limit)
                : block_size(_block_size), limit(_limit) {}

            virtual ~Access() {
                // std::cout << "~Destroying Access" << std::endl;
            }

            virtual uint64_t next_offset(void) = 0;
            virtual void validate(void) const;
            friend void from_json(const json& j, Access& access_generator);
    };

    class SequentialAccess : public Access {
        private:
            uint64_t current_offset;

        public:
            SequentialAccess();
            SequentialAccess(size_t _block_size, size_t _limit);

            ~SequentialAccess() override {
                // std::cout << "~Destroying SequentialAccess" << std::endl;
            }

            uint64_t next_offset(void) override;
            void validate(void) const;
            friend void from_json(const json& j, SequentialAccess& access_generator);
    };

    class RandomAccess : public Access {
        private:
            Distribution::UniformDistribution<uint64_t> distribution;

        public:
            RandomAccess();
            RandomAccess(size_t _block_size, size_t _limit);

            ~RandomAccess() override {
                // std::cout << "~Destroying RandomAccess" << std::endl;
            }

            uint64_t next_offset(void) override;
            void validate(void) const;
            friend void from_json(const json& j, RandomAccess& access_generator);
    };

    class ZipfianAccess : public Access {
        private:
            float skew;
            Distribution::ZipfianDistribution<uint64_t> distribution;

        public:
            ZipfianAccess();
            ZipfianAccess(size_t _block_size, size_t _limit, float _skew);

            ~ZipfianAccess() override {
                // std::cout << "~Destroying ZipfianAccess" << std::endl;
            }

            uint64_t next_offset(void) override;
            void validate(void) const;
            friend void from_json(const json& j, ZipfianAccess& access_generator);
    };

    void from_json(const json& j, Access& access_generator);
    void from_json(const json& j, SequentialAccess& access_generator);
    void from_json(const json& j, RandomAccess& access_generator);
    void from_json(const json& j, ZipfianAccess& access_generator);
};

#endif