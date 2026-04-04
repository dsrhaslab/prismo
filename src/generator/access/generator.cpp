#include <prismo/generator/access/generator.hpp>

namespace Generator {

    AccessGenerator::AccessGenerator(const nlohmann::json& j) {
        block_size = j.at("block_size").get<size_t>();
        partition_size = j.at("size").get<size_t>();

        if (block_size == 0) {
            throw std::invalid_argument(
                "AccessGenerator: block_size must be greater than zero");
        }

        size_t worker_id = j.at("worker_id").get<size_t>();
        size_t num_workers = j.at("num_workers").get<size_t>();

        size_t total_blocks = partition_size / block_size;
        size_t blocks_per_worker = total_blocks / num_workers;

        partition_start = worker_id * blocks_per_worker * block_size;

        if (worker_id == num_workers - 1) {
            partition_size = (total_blocks - worker_id * blocks_per_worker) * block_size;
        } else {
            partition_size = blocks_per_worker * block_size;
        }

        if (block_size > partition_size) {
            throw std::invalid_argument(
                "AccessGenerator: block_size must be less than or equal to size");
        }
    }

    AccessGenerator::~AccessGenerator() {
        std::cout << "~Destroying AccessGenerator" << std::endl;
    }

    SequentialAccessGenerator::~SequentialAccessGenerator() {
        std::cout << "~Destroying SequentialAccessGenerator" << std::endl;
    }

    SequentialAccessGenerator::SequentialAccessGenerator(const nlohmann::json& j)
        : AccessGenerator(j) {
        partition_size = block_size * (partition_size / block_size);
    }

    uint64_t SequentialAccessGenerator::next_offset(void) {
        const uint64_t offset = current_offset + partition_start;
        current_offset =
            static_cast<uint64_t>((current_offset + block_size) % partition_size);
        return offset;
    }

    RandomAccessGenerator::~RandomAccessGenerator() {
        std::cout << "~Destroying RandomAccessGenerator" << std::endl;
    }

    RandomAccessGenerator::RandomAccessGenerator(const nlohmann::json& j)
        : AccessGenerator(j) {
        normalized_partition_size = partition_size / block_size - 1;
        rng.setParams(0, normalized_partition_size);
    }

    uint64_t RandomAccessGenerator::next_offset(void) {
        return static_cast<uint64_t>(rng.nextValue() * block_size) + partition_start;
    }

    ZipfianAccessGenerator::~ZipfianAccessGenerator() {
        std::cout << "~Destroying ZipfianAccessGenerator" << std::endl;
    }

    ZipfianAccessGenerator::ZipfianAccessGenerator(const nlohmann::json& j)
        : AccessGenerator(j) {
        skew = j.value("skew", 0.0f);

        if (skew <= 0 || skew >= 1) {
            throw std::invalid_argument(
                "ZipfianAccessGenerator: skew must belong to range [0; 1]");
        }

        normalized_partition_size = partition_size / block_size - 1;
        distribution.setParams(0, normalized_partition_size, skew);
    }

    uint64_t ZipfianAccessGenerator::next_offset(void) {
        return static_cast<uint64_t>(distribution.nextValue() * block_size) + partition_start;
    }
}
