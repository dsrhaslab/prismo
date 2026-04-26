#include <prismo/generator/content/deduplication.hpp>

namespace Generator {

    DeduplicationContentGenerator::DeduplicationContentGenerator(const nlohmann::json& j)
        : ContentGenerator(j),
          pool(j.at("block_size").get<size_t>()),
          dedup_distribution(
            [&]() {
                std::vector<uint32_t> values, weights;
                for (const auto& item : j.at("distribution")) {
                    uint32_t repeats = item.at("repeats").get<uint32_t>();
                    values.push_back(repeats);
                    weights.push_back(item.at("percentage").get<uint32_t>());

                    if (item.contains("compression")) {
                        compression_generators.emplace(repeats, item.at("compression"));
                    }
                }
                return Distribution::DiscreteDistribution<uint32_t>(
                    "deduplication_distribution", values, weights);
            }()
        )
    {}

    BlockMetadata DeduplicationContentGenerator::next_block(
        uint8_t* buffer,
        size_t size
    ) {
        BlockMetadata meta;
        uint32_t repeats = dedup_distribution.nextValue();

        if (repeats == 0) {
            meta = generate_new_block(buffer, size, repeats);
        } else if (dedup_windows[repeats].size() == DEDUP_WINDOW_SIZE) {
            meta = reuse_dedup_element(buffer, size, repeats);
        } else {
            meta = create_dedup_element(buffer, size, repeats);
        }

        return meta;
    }

    BlockMetadata DeduplicationContentGenerator::generate_new_block(
        uint8_t* buffer,
        size_t size,
        uint32_t repeats
    ) {
        uint64_t this_block_id = block_id++;
        auto compression_generator = compression_generators.find(repeats);

        refill(buffer, size);
        uint32_t compression = 0;
        if (compression_generator != compression_generators.end()) {
            compression = compression_generator->second.apply(buffer, size);
        }

        std::memcpy(buffer, &this_block_id, sizeof(this_block_id));
        return BlockMetadata{
            .block_id = this_block_id,
            .compression = compression
        };
    }

    BlockMetadata DeduplicationContentGenerator::create_dedup_element(
        uint8_t* buffer,
        size_t size,
        uint32_t repeats
    ) {
        uint8_t* element_buffer = static_cast<uint8_t*>(pool.malloc());
        BlockMetadata meta = generate_new_block(element_buffer, size, repeats);
        std::memcpy(buffer, element_buffer, size);

        DedupElement element = {
            .block_id = meta.block_id,
            .left_repeats = repeats,
            .compression = meta.compression,
            .buffer = element_buffer
        };

        dedup_windows[repeats].push_back(element);
        return meta;
    }

    BlockMetadata DeduplicationContentGenerator::reuse_dedup_element(
        uint8_t* buffer,
        size_t size,
        uint32_t repeats
    ) {
        std::vector<DedupElement>& window = dedup_windows[repeats];
        uint32_t index = rng.nextValue() % window.size();

        DedupElement element = window[index];
        std::memcpy(buffer, element.buffer, size);

        window[index].left_repeats--;

        if (window[index].left_repeats == 0) {
            pool.free(window[index].buffer);
            std::swap(window[index], window.back());
            window.pop_back();
        }

        return BlockMetadata{
            .block_id = element.block_id,
            .compression = element.compression
        };
    }
}