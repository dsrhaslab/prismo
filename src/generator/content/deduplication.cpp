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
        DedupElement element;
        uint32_t repeats = dedup_distribution.nextValue();

        if (repeats == 0) {
            element = create_dedup_element(repeats, buffer, size);
        } else if (dedup_windows[repeats].size() == DEDUP_WINDOW_SIZE) {
            element = reuse_dedup_element(repeats, buffer, size);
        } else {
            element = create_dedup_element(repeats, buffer, size);
            dedup_windows[repeats].push_back(element);
        }

        return BlockMetadata{
            .block_id = element.block_id,
            .compression = element.compression
        };
    }

    DedupElement DeduplicationContentGenerator::create_dedup_element(
        uint32_t repeats,
        uint8_t* buffer,
        size_t size
    ) {
        auto compression_generator = compression_generators.find(repeats);

        DedupElement element = {
            .block_id = block_id++,
            .left_repeats = repeats,
            .compression = 0,
            .buffer = static_cast<uint8_t*>(pool.malloc()),
        };

        // improve memcpy to not overlap compression area
        // maybe not because size could be strange for random generator
        refill(element.buffer, size);
        if (compression_generator != compression_generators.end()) {
            element.compression =
                compression_generator->second.apply(element.buffer, size);
        }

        std::memcpy(
            element.buffer,
            &element.block_id,
            sizeof(element.block_id)
        );

        std::memcpy(buffer, element.buffer, size);

        return element;
    }

    DedupElement DeduplicationContentGenerator::reuse_dedup_element(
        uint32_t repeats,
        uint8_t* buffer,
        size_t size
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

        return element;
    }
}