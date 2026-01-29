#ifndef PARSER_TRACE_READER_H
#define PARSER_TRACE_READER_H

#include <cstddef>
#include <string>
#include <fstream>
#include <vector>
#include <optional>
#include <common/trace.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace Parser {

    struct TraceReaderConfig {
        size_t buffer_memory;
        std::string trace_file;

        friend void from_json(const json& j, TraceReaderConfig& config) {
            j.at("buffer_memory").get_to(config.buffer_memory);
            j.at("trace_file").get_to(config.trace_file);
        };
    };

    class TraceReader {
        private:
            std::ifstream trace_file;
            std::vector<Trace::Record> buffer;

            size_t records_read = 0;
            size_t current_position = 0;

        public:
            TraceReader() = default;

            TraceReader(const TraceReaderConfig& config) :
                trace_file(config.trace_file, std::ios::binary),
                buffer(config.buffer_memory / sizeof(Trace::Record))
            {
                if (!trace_file.is_open()) {
                    throw std::runtime_error("Failed to open trace file: " + config.trace_file);
                }
            };

            ~TraceReader() {
                trace_file.close();
            };

            void reset(void) {
                records_read = 0;
                current_position = 0;
                trace_file.clear();
                trace_file.seekg(0, std::ios::beg);
                if (trace_file.fail()) {
                    throw std::runtime_error("Failed to reset trace file");
                }
            };

            std::optional<Trace::Record> next_record(void) {
                if (current_position >= records_read) {
                    const std::streamsize bytes_to_read =
                        static_cast<std::streamsize>(buffer.capacity() * sizeof(Trace::Record));

                    trace_file.read(reinterpret_cast<char*>(buffer.data()), bytes_to_read);

                    const std::streamsize bytes_read = trace_file.gcount();
                    records_read = static_cast<std::size_t>(bytes_read) / sizeof(Trace::Record);
                    current_position = 0;

                    if (bytes_read <= 0) {
                        return std::nullopt;;
                    }
                }

                return buffer[current_position++];
            };
    };
}

#endif