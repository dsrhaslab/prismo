#ifndef PRISMO_WORKER_TERMINATION_H
#define PRISMO_WORKER_TERMINATION_H

#include <chrono>
#include <cstdint>
#include <string>
#include <stdexcept>
#include <nlohmann/json.hpp>

namespace Worker::Internal {

    enum class TerminationType {
        ITERATIONS,
        RUNTIME
    };

    class Termination {
        private:
            static constexpr uint64_t CHECK_INTERVAL = 4096;
            TerminationType type;
            uint64_t value;

        public:
            Termination() = default;

            ~Termination() {
                std::cout << "~Destroying Termination" << std::endl;
            }

            explicit Termination(const nlohmann::json& j) {
                value = j.at("value").get<uint64_t>();
                std::string type_str = j.at("type").get<std::string>();

                if (type_str == "iterations") {
                    type = TerminationType::ITERATIONS;
                } else if (type_str == "runtime") {
                    type = TerminationType::RUNTIME;
                } else {
                    throw std::invalid_argument(
                        "Termination: unknown type '" + type_str + "'");
                }
            }

            bool should_continue(
                const std::chrono::steady_clock::time_point& start_time,
                uint64_t iterations_count
            ) const {
                switch (type) {
                    case TerminationType::ITERATIONS:
                        return iterations_count < value;

                    case TerminationType::RUNTIME: {
                        auto current_time =
                            (iterations_count % CHECK_INTERVAL == 0)
                                ? std::chrono::steady_clock::now()
                                : start_time;

                        auto elapsed =
                            std::chrono::duration_cast<std::chrono::milliseconds>(
                                current_time - start_time)
                                .count();

                        return elapsed < static_cast<long>(value);
                    }

                    default:
                        throw std::invalid_argument(
                            "should_continue: invalid termination type");
                }
            }
    };
}

#endif
