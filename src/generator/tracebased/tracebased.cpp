#include <prismo/generator/tracebased/tracebased.hpp>

namespace Generator {

    TraceBased::~TraceBased() {
        std::cout << "~Destroying TraceBased" << std::endl;
    }

    TraceBased::TraceBased(std::unique_ptr<Extension::TraceExtension> ext)
        : extension(std::move(ext)) {}

    TraceBasedAccessGenerator::~TraceBasedAccessGenerator() {
        std::cout << "~Destroying TraceBasedAccessGenerator" << std::endl;
    }

    TraceBasedAccessGenerator::TraceBasedAccessGenerator(
        const nlohmann::json& j,
        std::unique_ptr<Extension::TraceExtension> ext
    ) : AccessGenerator(j), TraceBased(std::move(ext)) {}

    uint64_t TraceBasedAccessGenerator::next_offset(void) {
        return extension->next_record().offset % partition_size + partition_start;
    }

    TraceBasedOperationGenerator::~TraceBasedOperationGenerator() {
        std::cout << "~Destroying TraceBasedOperationGenerator" << std::endl;
    }

    TraceBasedOperationGenerator::TraceBasedOperationGenerator(
        std::unique_ptr<Extension::TraceExtension> ext
    ) : TraceBased(std::move(ext)) {}

    Operation::OperationType TraceBasedOperationGenerator::next_operation(void) {
        return extension->next_record().operation;
    }

    TraceBasedContentGenerator::~TraceBasedContentGenerator() {
        std::cout << "~Destroying TraceBasedContentGenerator" << std::endl;
    }

    TraceBasedContentGenerator::TraceBasedContentGenerator(
        const nlohmann::json& j,
        std::unique_ptr<Extension::TraceExtension> ext
    ) : ContentGenerator(j, false), TraceBased(std::move(ext)) {}

    BlockMetadata TraceBasedContentGenerator::next_block(uint8_t* buffer, size_t size) {
        refill(buffer, size);
        Trace::Record record = extension->next_record();
        std::memcpy(buffer, &record.block_id, sizeof(record.block_id));
        return BlockMetadata {
            .block_id = record.block_id,
            .compression = 0
        };
    }
}
