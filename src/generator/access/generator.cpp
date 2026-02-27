#include <prismo/generator/access/generator.hpp>

namespace Generator {

    AccessGenerator::AccessGenerator(const nlohmann::json& j) {
        block_size = j.at("block_size").get<size_t>();
        limit = j.at("limit").get<size_t>();

        if (block_size == 0) {
            throw std::invalid_argument(
                "AccessGenerator: block_size must be greater than zero");
        } else if (block_size > limit) {
            throw std::invalid_argument(
                "AccessGenerator: block_size must be less than or equal to limit");
        }
    }

    AccessGenerator::~AccessGenerator() {
        std::cout << "~Destroying AccessGenerator" << std::endl;
    }

    SequentialAccessGenerator::~SequentialAccessGenerator() {
        std::cout << "~Destroying SequentialAccessGenerator" << std::endl;
    }

    SequentialAccessGenerator::SequentialAccessGenerator(
        const nlohmann::json& j)
        : AccessGenerator(j) {
        limit = block_size * (limit / block_size);
    }

    uint64_t SequentialAccessGenerator::next_offset(void) {
        const uint64_t offset = current_offset;
        current_offset =
            static_cast<uint64_t>((current_offset + block_size) % limit);
        return offset;
    }

    RandomAccessGenerator::~RandomAccessGenerator() {
        std::cout << "~Destroying RandomAccessGenerator" << std::endl;
    }

    RandomAccessGenerator::RandomAccessGenerator(const nlohmann::json& j)
        : AccessGenerator(j) {
        normalized_limit = limit / block_size - 1;
        rng.setParams(0, normalized_limit);
    }

    uint64_t RandomAccessGenerator::next_offset(void) {
        return static_cast<uint64_t>(rng.nextValue() * block_size);
    }

    ZipfianAccessGenerator::~ZipfianAccessGenerator() {
        std::cout << "~Destroying ZipfianAccessGenerator" << std::endl;
    }

    ZipfianAccessGenerator::ZipfianAccessGenerator(const nlohmann::json& j)
        : AccessGenerator(j) {
        skew = j.at("skew").get<float>();

        if (skew <= 0 || skew >= 1) {
            throw std::invalid_argument(
                "ZipfianAccessGenerator: skew must belong to range [0; 1]");
        }

        normalized_limit = limit / block_size - 1;
        distribution.setParams(0, normalized_limit, skew);
    }

    uint64_t ZipfianAccessGenerator::next_offset(void) {
        return static_cast<uint64_t>(distribution.nextValue() * block_size);
    }
}
