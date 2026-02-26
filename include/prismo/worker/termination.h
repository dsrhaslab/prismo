#ifndef PRISMO_WORKER_TERMINATION_H
#define PRISMO_WORKER_TERMINATION_H

#include <chrono>
#include <cstdint>
#include <string>
#include <stdexcept>
#include <nlohmann/json.hpp>

namespace Worker {

    enum class TerminationType {
        ITERATIONS,
        RUNTIME
    };

    struct Termination {
        TerminationType type;
        uint64_t value;
    };

    class TerminationManager {
        private:
            static constexpr uint64_t CHECK_INTERVAL = 4096;

        public:
            static inline bool should_continue(
                const Termination& termination,
                const std::chrono::steady_clock::time_point& start_time,
                uint64_t iterations_count
            ) {
                switch (termination.type) {
                    case TerminationType::ITERATIONS:
                        return iterations_count < termination.value;

                    case TerminationType::RUNTIME: {
                        auto current_time =
                            (iterations_count % CHECK_INTERVAL == 0)
                                ? std::chrono::steady_clock::now()
                                : start_time;

                        auto elapsed =
                            std::chrono::duration_cast<std::chrono::milliseconds>(
                                current_time - start_time)
                                .count();

                        return elapsed < static_cast<long>(termination.value);
                    }

                    default:
                        throw std::invalid_argument("should_continue: invalid termination type");
                }
            }

            static Termination parse(const nlohmann::json& config) {
                TerminationType type;
                uint64_t value = config.at("value").get<uint64_t>();
                std::string type_str = config.at("type").get<std::string>();

                if (type_str == "iterations") {
                    type = TerminationType::ITERATIONS;
                } else if (type_str == "runtime") {
                    type = TerminationType::RUNTIME;
                } else {
                    throw std::invalid_argument(
                        "parse: unknown termination type '" + type_str + "'");
                }

                return Termination{.type = type, .value = value};
            }
    };

}

#endif
