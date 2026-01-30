#ifndef REALISTIC_REPEAT_GENERATOR_H
#define REALISTIC_REPEAT_GENERATOR_H

#include <prismo/parser/trace-reader.h>
#include <prismo/generator/access/generator.h>
#include <prismo/generator/content/generator.h>
#include <prismo/generator/operation/generator.h>

namespace Generator {

    class RealisticRepeatGenerator :
        public AccessGenerator,
        public OperationGenerator,
        public ContentGenerator
    {
        private:
            std::optional<Parser::TraceReader> trace_reader;

            Trace::Record next_record() {
                auto record = trace_reader->next_record();
                std::cout << "ola2" << std::endl;
                if (!record.has_value()) {
                    std::cout << "Resetting trace reader" << std::endl;
                    trace_reader->reset();
                    std::cout << "Reading next record after reset" << std::endl;
                    record = trace_reader->next_record();
                }
                std::cout << "ola3" << std::endl;
                return record.value();
            }

        public:
            RealisticRepeatGenerator() = delete;

            ~RealisticRepeatGenerator() override {
                std::cout << "~Destroying RealisticRepeatGenerator" << std::endl;
            };

            explicit RealisticRepeatGenerator(const json& j)
                : AccessGenerator(j), trace_reader(j) {};

            void validate(void) const override {
                AccessGenerator::validate();
            }

            uint64_t next_offset(void) override {
                std::cout << "ola" << std::endl;
                Trace::Record record = next_record();
                std::cout << "ola" << std::endl;
                return record.offset % limit;
            };

            Operation::OperationType next_operation(void) override {
                Trace::Record record = next_record();
                return record.operation;
            };

            BlockMetadata next_block(uint8_t* buffer, size_t size) override {
                Trace::Record record = next_record();
                std::memset(buffer, 0, size);
                std::memcpy(buffer, &record.block_id, sizeof(record.block_id));
                return BlockMetadata {
                    .block_id = record.block_id,
                    .compression = 100
                };
            };
    };
};

#endif