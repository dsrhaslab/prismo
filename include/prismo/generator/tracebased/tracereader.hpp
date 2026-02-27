#ifndef PRISMO_GENERATOR_TRACEBASED_TRACEREADER_H
#define PRISMO_GENERATOR_TRACEBASED_TRACEREADER_H

#include <vector>
#include <cstddef>
#include <string>
#include <fstream>
#include <optional>
#include <iostream>
#include <nlohmann/json.hpp>
#include <common/trace.hpp>

namespace Generator::Parser {

    class TraceReader {
        private:
            std::ifstream trace_file;
            std::vector<Trace::Record> buffer;

            size_t records_read = 0;
            size_t current_position = 0;

        public:
            TraceReader() = delete;

            explicit TraceReader(const nlohmann::json& j);

            ~TraceReader();

            void reset(void);

            std::optional<Trace::Record> next_record(void);
    };
}

#endif