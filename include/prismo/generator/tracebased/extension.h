#ifndef TRACE_BASED_EXTENSION_H
#define TRACE_BASED_EXTENSION_H

#include <iostream>
#include <optional>
#include <common/trace.h>
#include <prismo/parser/trace-reader.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace Extension {

    class TraceExtension {
        public:
            TraceExtension() = default;

            virtual ~TraceExtension() {
                std::cout << "~Destroying TraceExtension" << std::endl;
            }

            virtual Trace::Record next_record() = 0;
    };

    class RepeatExtension : public TraceExtension {
        private:
            std::optional<Parser::TraceReader> trace_reader;

        public:
            RepeatExtension() = delete;

            ~RepeatExtension() override {
                std::cout << "~Destroying RepeatExtension" << std::endl;
            }

            explicit RepeatExtension(const json& j)
                : trace_reader(j) {}

            Trace::Record next_record() override {
                auto record = trace_reader->next_record();
                if (!record.has_value()) {
                    trace_reader->reset();
                    record = trace_reader->next_record();
                }
                return record.value();
            }
        };
}

#endif