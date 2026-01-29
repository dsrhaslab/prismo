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
            Parser::TraceReader trace_reader;

            Trace::Record next_record(void) {
                std::optional<Trace::Record> record = trace_reader.next_record();
                if (!record.has_value()) {
                    trace_reader.reset();
                    record = trace_reader.next_record();
                }
                return record.value();
            };

        public:
            RealisticRepeatGenerator() = default;

            RealisticRepeatGenerator(const Parser::TraceReaderConfig& trace_reader_config)
                : AccessGenerator(), OperationGenerator(), ContentGenerator(),
                trace_reader(trace_reader_config) {};

            ~RealisticRepeatGenerator() override {
                std::cout << "~Destroying RealisticRepeatGenerator" << std::endl;
            };

            uint64_t next_offset(void) override {
                Trace::Record record = next_record();
                return record.offset;
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