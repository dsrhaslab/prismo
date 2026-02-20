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
        DedupElement element;
        uint32_t dedup_roll = rng.nextValue();
        uint32_t repeats = select_from_percentage_vector(dedup_roll, dedup_percentages);

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
        auto& compression_generator = compression_generators[repeats];

        DedupElement element = {
            .block_id = block_id++,
            .left_repeats = repeats,
            .compression = compression_generator.select_compression(),
            .buffer = static_cast<uint8_t*>(pool.malloc()),
        };

        // improve memcpy to not overlap compression area
        // maybe not because size could be strange for random generator
        refill(element.buffer, size);
        element.compression =
            compression_generator.apply(element.buffer, size);

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