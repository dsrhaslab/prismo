#include <prismo/generator/content/generator.hpp>

namespace Generator {

    ContentGenerator::ContentGenerator(const nlohmann::json& j)
        : ContentGenerator(j, j.value("refill", false)) {}

    ContentGenerator::ContentGenerator(const nlohmann::json& j, bool _refill_flag)
        : refill_flag(_refill_flag),
        base_buffer(j.at("block_size").get<size_t>()) {
        prng_init(&shishua_prng, generate_seed().data());
        prng_gen(&shishua_prng, base_buffer.data(), base_buffer.size());
    }

    void ContentGenerator::refill(uint8_t* buffer, size_t size) {
        if (refill_flag) {
            prng_gen(&shishua_prng, buffer, size);
        } else {
            std::memcpy(buffer, base_buffer.data(), size);
        }
    }

    ContentGenerator::~ContentGenerator() {
        std::cout << "~Destroying ContentGenerator" << std::endl;
    }

    ConstantContentGenerator::~ConstantContentGenerator() {
        std::cout << "~Destroying ConstantContentGenerator" << std::endl;
    }

    ConstantContentGenerator::ConstantContentGenerator(const nlohmann::json& j)
        : ContentGenerator(j, false) {}

    BlockMetadata ConstantContentGenerator::next_block(uint8_t* buffer, size_t size) {
        refill(buffer, size);
        std::memcpy(buffer, &block_id, sizeof(block_id));
        return BlockMetadata {
            .block_id = block_id,
            .compression = 0
        };
    }

    RandomContentGenerator::~RandomContentGenerator() {
        std::cout << "~Destroying RandomContentGenerator" << std::endl;
    }

    RandomContentGenerator::RandomContentGenerator(const nlohmann::json& j)
        : ContentGenerator(j) {}

    BlockMetadata RandomContentGenerator::next_block(uint8_t* buffer, size_t size) {
        refill(buffer, size);
        block_id = rng.nextValue();
        std::memcpy(buffer, &block_id, sizeof(block_id));
        return BlockMetadata {
            .block_id = block_id,
            .compression = 0
        };
    }
}
