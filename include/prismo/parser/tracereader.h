#ifndef PARSER_TRACE_READER_H
#define PARSER_TRACE_READER_H

#include <vector>
#include <cstddef>
#include <string>
#include <fstream>
#include <optional>
#include <iostream>
#include <common/trace.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace Parser {

    class TraceReader {
        private:
            std::ifstream trace_file;
            std::vector<Trace::Record> buffer;

            size_t records_read = 0;
            size_t current_position = 0;

        public:
            TraceReader() = delete;

            explicit TraceReader(const json& j) {
                const std::string trace_path = j.at("trace").get<std::string>();
                const size_t memory_bytes = j.at("memory").get<size_t>();

                if (memory_bytes < sizeof(Trace::Record)) {
                    throw std::invalid_argument(
                        "TraceReader: memory should be equal or greater than " +
                            std::to_string(sizeof(Trace::Record))
                    );
                }

                trace_file.open(trace_path, std::ios::binary);
                if (!trace_file.is_open()) {
                    throw std::runtime_error("Failed to open trace file: " + trace_path);
                }

                buffer.resize(memory_bytes / sizeof(Trace::Record));
            }

            ~TraceReader() {
                std::cout << "~Destroying TraceReader" << std::endl;
                if (trace_file.is_open()) {
                    trace_file.close();
                }
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

                    // std::cout << "Reading " << bytes_to_read << " bytes from trace file" << std::endl;
                    // std::cout << bytes_read << " bytes read from trace file" << std::endl;

                    records_read = static_cast<std::size_t>(bytes_read) / sizeof(Trace::Record);
                    current_position = 0;

                    if (bytes_read <= 0) {
                        return std::nullopt;
                    }

                    // std::cout << records_read << " records read into buffer" << std::endl;
                    // std::cout << "Current position reset to 0" << std::endl;
                }

                return buffer[current_position++];
            };
    };
}

#endif