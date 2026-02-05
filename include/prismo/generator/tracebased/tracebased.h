#ifndef TRACE_BASED_GENERATOR_H
#define TRACE_BASED_GENERATOR_H

#include <prismo/generator/access/generator.h>
#include <prismo/generator/operation/generator.h>
#include <prismo/generator/content/generator.h>
#include <prismo/generator/tracebased/extension.h>

namespace Generator {

    class TraceBased {
        protected:
            std::unique_ptr<Extension::TraceExtension> extension;

            TraceBased() = delete;

            virtual ~TraceBased() {
                std::cout << "~Destroying TraceBased" << std::endl;
            }

            explicit TraceBased(std::unique_ptr<Extension::TraceExtension> ext)
                : extension(std::move(ext)) {}
    };


    class TraceBasedAccessGenerator : public AccessGenerator, public TraceBased {
        public:
            TraceBasedAccessGenerator() = delete;

            virtual ~TraceBasedAccessGenerator() {
                std::cout << "~Destroying TraceBasedAccessGenerator" << std::endl;
            }

            explicit TraceBasedAccessGenerator(const json& j, std::unique_ptr<Extension::TraceExtension> ext)
                : AccessGenerator(j), TraceBased(std::move(ext)) {}

            void validate(void) const override {
                AccessGenerator::validate();
            }

            uint64_t next_offset(void) override {
                return extension->next_record().offset;
            }
    };


    class TraceBasedOperationGenerator : public OperationGenerator, public TraceBased {
        public:
            TraceBasedOperationGenerator() = delete;

            virtual ~TraceBasedOperationGenerator() {
                std::cout << "~Destroying TraceBasedOperationGenerator" << std::endl;
            }

            explicit TraceBasedOperationGenerator(std::unique_ptr<Extension::TraceExtension> ext)
                : OperationGenerator(), TraceBased(std::move(ext)) {}

            void validate(void) const override {};

            Operation::OperationType next_operation(void) override {
                return extension->next_record().operation;
            };
    };


    class TraceBasedContentGenerator : public ContentGenerator, public TraceBased {
        public:
            TraceBasedContentGenerator() = delete;

            virtual ~TraceBasedContentGenerator() {
                std::cout << "~Destroying TraceBasedContentGenerator" << std::endl;
            }

            explicit TraceBasedContentGenerator(const json& j, std::unique_ptr<Extension::TraceExtension> ext)
                : ContentGenerator(j, false), TraceBased(std::move(ext)) {}

            void validate(void) const override {}

            BlockMetadata next_block(uint8_t* buffer, size_t size) override {
                refill(buffer, size);
                Trace::Record record = extension->next_record();
                std::memcpy(buffer, &record.block_id, sizeof(record.block_id));
                return BlockMetadata {
                    .block_id = record.block_id,
                    .compression = 0
                };
            }
    };

}

#endif
