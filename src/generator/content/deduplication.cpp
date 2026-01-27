#include <prismo/generator/content/deduplication.h>

namespace Generator {

    DeduplicationContentGenerator::DeduplicationContentGenerator(
        const DeduplicationContentGeneratorConfig& _config
    ) :
        ContentGenerator(),
        pool(_config.get_block_size()),
        config(_config),
        distribution(0, 99)
    {
        refill_buffer = std::make_unique<uint8_t[]>(config.get_block_size());
        random_generator.next_block(refill_buffer.get(), config.get_block_size());
    }

    BlockMetadata DeduplicationContentGenerator::next_block(
        uint8_t* buffer,
        size_t size
    ) {
        uint32_t deduplication_roll = distribution.nextValue();
        uint32_t compression_roll = distribution.nextValue();

        uint32_t selected_repeats = config.select_repeats(deduplication_roll);
        uint32_t selected_compression = config.select_compression(compression_roll, selected_repeats);

        if (selected_repeats == 0) {
            DedupElement element = create_dedup_element(selected_repeats, selected_compression, size);
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

        DedupElement element = create_dedup_element(selected_repeats, selected_compression, size);
        dedup_windows[selected_repeats].push_back(element);
        std::memcpy(buffer, element.buffer, size);

        return BlockMetadata {
            .block_id = element.block_id,
            .compression = selected_compression
        };
    }

    DedupElement DeduplicationContentGenerator::create_dedup_element(
        uint32_t repeats,
        uint32_t compression,
        size_t size
    ) {
        DedupElement dedup_element = {
            .block_id = block_id++,
            .left_repeats = repeats,
            .compression = compression,
            .buffer = static_cast<uint8_t*>(pool.malloc()),
        };

        // improve memcpy to not overlap compression area
        // maybe not because size could be strange for random generator
        if (config.get_refill_buffers()) {
            random_generator.next_block(dedup_element.buffer, size);
        } else {
            std::memcpy(dedup_element.buffer, refill_buffer.get(), size);
        }

        apply_compression(dedup_element.buffer, size, compression);

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
        uint32_t index = distribution.nextValue() % dedup_window.size();
        DedupElement& element = dedup_window[index];

        element.left_repeats--;
        std::memcpy(buffer, element.buffer, size);

        if (element.left_repeats == 0) {
            std::swap(dedup_window[index], dedup_window.back());
            dedup_window.pop_back();
            pool.free(element.buffer);
        }

        return element;
    }
}