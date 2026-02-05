#include <prismo/generator/content/deduplication.h>

namespace Generator {

    DeduplicationContentGenerator::DeduplicationContentGenerator(const json& j)
        : ContentGenerator(j), pool(j.at("block_size").get<size_t>()), rng(0, 99)
    {
        uint32_t cumulative_deduplication = 0;
        for (const auto& dedup_item : j.at("distribution")) {
            uint32_t repeats = dedup_item.at("repeats").get<uint32_t>();
            cumulative_deduplication += dedup_item.at("percentage").get<uint32_t>();

            compression_generators.emplace(repeats, dedup_item.at("compression"));
            dedup_percentages.push_back(PercentageElement<uint32_t, uint32_t> {
                .cumulative_percentage = cumulative_deduplication,
                .value = repeats,
            });
        }
    }

    BlockMetadata DeduplicationContentGenerator::next_block(
        uint8_t* buffer,
        size_t size
    ) {
        uint32_t deduplication_roll = rng.nextValue();
        uint32_t selected_repeats = select_from_percentage_vector(
            deduplication_roll,
            dedup_percentages
        );

        if (selected_repeats == 0) {
            DedupElement element = create_dedup_element(selected_repeats, size);
            std::memcpy(buffer, element.buffer, size);
            return BlockMetadata {
                .block_id = element.block_id,
                .compression = element.compression,
            };
        }

        if (dedup_windows[selected_repeats].size() == DEDUP_WINDOW_SIZE) {
            DedupElement element = reuse_dedup_element(selected_repeats, buffer, size);
            return BlockMetadata {
                .block_id = element.block_id,
                .compression = element.compression,
            };
        }

        DedupElement element = create_dedup_element(selected_repeats, size);
        dedup_windows[selected_repeats].push_back(element);
        std::memcpy(buffer, element.buffer, size);

        return BlockMetadata {
            .block_id = element.block_id,
            .compression = element.compression
        };
    }

    DedupElement DeduplicationContentGenerator::create_dedup_element(
        uint32_t repeats,
        size_t size
    ) {
        auto& compression_generator = compression_generators[repeats];

        DedupElement dedup_element = {
            .block_id = block_id++,
            .left_repeats = repeats,
            .compression = compression_generator.select_compression(),
            .buffer = static_cast<uint8_t*>(pool.malloc()),
        };

        // improve memcpy to not overlap compression area
        // maybe not because size could be strange for random generator
        refill(dedup_element.buffer, size);
        apply_compression(dedup_element.buffer, size, dedup_element.compression);

        std::memcpy(
            dedup_element.buffer,
            &dedup_element.block_id,
            sizeof(dedup_element.block_id)
        );

        return dedup_element;
    }

    DedupElement DeduplicationContentGenerator::reuse_dedup_element(
        uint32_t repeats,
        uint8_t* buffer,
        size_t size
    ) {
        std::vector<DedupElement>& dedup_window = dedup_windows[repeats];
        uint32_t index = rng.nextValue() % dedup_window.size();
        DedupElement& dedup_element = dedup_window[index];

        dedup_element.left_repeats--;
        std::memcpy(buffer, dedup_element.buffer, size);

        if (dedup_element.left_repeats == 0) {
            std::swap(dedup_window[index], dedup_window.back());
            dedup_window.pop_back();
            pool.free(dedup_element.buffer);
        }

        return dedup_element;
    }
}