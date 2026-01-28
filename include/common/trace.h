#ifndef TRACE_H
#define TRACE_H

#include <cstdint>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace Trace {

    struct Record {
        uint64_t timestamp;
        uint32_t pid;
        char     process[64];
        uint64_t offset;
        uint32_t size;
        char     rw;
        uint32_t major;
        uint32_t minor;
        uint8_t  hash[64];
    };

    struct ReaderConfig {
        size_t buffer_memory;
        std::string trace_file;

        friend void from_json(const json& j, ReaderConfig& config) {
            j.at("buffer_memory").get_to(config.buffer_memory);
            j.at("trace_file").get_to(config.trace_file);
        };
    };

    class Reader {
        private:
            std::ifstream trace_file;
            std::vector<Record> buffer;
            size_t current_position = 0;

        public:
            Reader() = default;

            Reader(const ReaderConfig& config) :
                trace_file(config.trace_file, std::ios::binary),
                buffer(config.buffer_memory / sizeof(Record))
            {
                if (!trace_file.is_open()) {
                    throw std::runtime_error("Failed to open trace file: " + config.trace_file);
                }
            };

            ~Reader() {
                trace_file.close();
            };

            void reset(void) {
                trace_file.clear();
                trace_file.seekg(0, std::ios::beg);
                current_position = 0;
                if (trace_file.fail()) {
                    throw std::runtime_error("Failed to reset trace file");
                }
            };

            std::optional<Record> next_record(void) {
                if (current_position >= buffer.size()) {
                    const std::streamsize bytes_to_read =
                        static_cast<std::streamsize>(buffer.capacity() * sizeof(Record));

                    trace_file.read(reinterpret_cast<char*>(buffer.data()), bytes_to_read);

                    const std::streamsize bytes_read = trace_file.gcount();
                    const std::size_t records_read =
                        static_cast<std::size_t>(bytes_read) / sizeof(Record);

                    if (bytes_read <= 0) {
                        return std::nullopt;;
                    }

                    buffer.resize(records_read);
                    current_position = 0;
                }

                return buffer[current_position++];
            };
    };
}

#endif