#ifndef PRISMO_CONTROL_TERMINATION_H
#define PRISMO_CONTROL_TERMINATION_H

#include <chrono>
#include <cstdint>
#include <iomanip>
#include <sstream>
#include <string>
#include <iostream>
#include <stdexcept>
#include <nlohmann/json.hpp>

namespace Control {

    inline constexpr uint64_t CHECK_INTERVAL = 4096;

    enum class TerminationType {
        ITERATIONS,
        RUNTIME
    };

    class Termination {
        private:
            uint64_t iterations_count;
            std::chrono::steady_clock::time_point start_time;

            TerminationType type;
            uint64_t value;

        public:
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

            void start(void) {
                start_time = std::chrono::steady_clock::now();
                iterations_count = 0;
            }

            void next_iteration(void) {
                iterations_count++;
            }

            std::chrono::steady_clock::time_point get_start_time(void) const {
                return start_time;
            }

            bool is_time_check_due(void) const {
                return iterations_count % CHECK_INTERVAL == 0;
            }

            bool should_continue(void) const {
                switch (type) {
                    case TerminationType::ITERATIONS:
                        return iterations_count < value;

                    case TerminationType::RUNTIME: {
                        auto current_time =
                            (is_time_check_due())
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

            std::string progress(void) const {
                std::ostringstream oss;
                oss << std::fixed << std::setprecision(1);

                switch (type) {
                    case TerminationType::ITERATIONS:
                        if (value == 0) {
                            oss << "0.0% (0/0)";
                        } else {
                            double percent = std::min(
                                100.0,
                                100.0 *
                                static_cast<double>(iterations_count) /
                                static_cast<double>(value)
                            );

                            oss << percent << "% (" << iterations_count << "/"
                               << value << ")";
                        }
                        break;

                    case TerminationType::RUNTIME: {
                        auto now = std::chrono::steady_clock::now();
                        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>
                            (now - start_time).count();

                        double elapsed_sec = elapsed / 1000.0;
                        double total_sec = static_cast<double>(value) / 1000.0;
                        double percent = total_sec > 0
                            ? std::min(100.0, elapsed_sec / total_sec * 100.0)
                            : 0.0;

                        oss << percent << "% (" << elapsed_sec << "s/"
                           << total_sec << "s)";
                        break;
                    }

                    default:
                        throw std::invalid_argument(
                            "progress: invalid termination type");
                }

                return oss.str();
            }
    };
}

#endif
