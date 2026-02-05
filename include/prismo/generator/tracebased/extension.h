#ifndef TRACE_BASED_EXTENSION_H
#define TRACE_BASED_EXTENSION_H

#include <iostream>
#include <optional>
#include <common/trace.h>
#include <nlohmann/json.hpp>
#include <prismo/parser/tracereader.h>

using json = nlohmann::json;

namespace Extension {

    class TraceExtension {
        protected:
            std::optional<Parser::TraceReader> trace_reader;

            TraceExtension() = delete;

            explicit TraceExtension(const json& j)
                : trace_reader(j) {}

        public:
            virtual ~TraceExtension() {
                std::cout << "~Destroying TraceExtension" << std::endl;
            }

            virtual Trace::Record next_record() = 0;
    };

    class RepeatExtension : public TraceExtension {
        public:
            RepeatExtension() = delete;

            ~RepeatExtension() override {
                std::cout << "~Destroying RepeatExtension" << std::endl;
            }

            explicit RepeatExtension(const json& j)
                : TraceExtension(j) {}

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