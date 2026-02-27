#ifndef PRISMO_GENERATOR_TRACEBASED_TRACEBASED_H
#define PRISMO_GENERATOR_TRACEBASED_TRACEBASED_H

#include <prismo/generator/access/generator.hpp>
#include <prismo/generator/operation/generator.hpp>
#include <prismo/generator/content/generator.hpp>
#include <prismo/generator/tracebased/extension.hpp>

namespace Generator {

    class TraceBased {
        protected:
            std::unique_ptr<Extension::TraceExtension> extension;

            TraceBased() = delete;

            virtual ~TraceBased();

            explicit TraceBased(std::unique_ptr<Extension::TraceExtension> ext);
    };


    class TraceBasedAccessGenerator : public AccessGenerator, public TraceBased {
        public:
            TraceBasedAccessGenerator() = delete;

            virtual ~TraceBasedAccessGenerator();

            explicit TraceBasedAccessGenerator(const nlohmann::json& j, std::unique_ptr<Extension::TraceExtension> ext);

            uint64_t next_offset(void) override;
    };


    class TraceBasedOperationGenerator : public OperationGenerator, public TraceBased {
        public:
            TraceBasedOperationGenerator() = delete;

            virtual ~TraceBasedOperationGenerator();

            explicit TraceBasedOperationGenerator(std::unique_ptr<Extension::TraceExtension> ext);

            Operation::OperationType next_operation(void) override;
    };


    class TraceBasedContentGenerator : public ContentGenerator, public TraceBased {
        public:
            TraceBasedContentGenerator() = delete;

            virtual ~TraceBasedContentGenerator();

            explicit TraceBasedContentGenerator(const nlohmann::json& j, std::unique_ptr<Extension::TraceExtension> ext);

            BlockMetadata next_block(uint8_t* buffer, size_t size) override;
    };

}

#endif
