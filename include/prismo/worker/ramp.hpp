#ifndef PRISMO_WORKER_RAMP_H
#define PRISMO_WORKER_RAMP_H

#include <algorithm>
#include <chrono>
#include <stdexcept>
#include <thread>
#include <nlohmann/json.hpp>

namespace Worker {

    struct Ramp {
        double start_ratio;
        double end_ratio;
        double duration_ms;

        Ramp() = delete;

        explicit Ramp(const nlohmann::json& j)
            : start_ratio(j.at("start_ratio").get<double>()),
              end_ratio(j.at("end_ratio").get<double>()),
              duration_ms(j.at("duration").get<double>())
        {
            if (start_ratio <= 0.0 || start_ratio > 1.0) {
                throw std::invalid_argument("Ramp: start_ratio must be in (0.0, 1.0]");
            }
            if (end_ratio <= 0.0 || end_ratio > 1.0) {
                throw std::invalid_argument("Ramp: end_ratio must be in (0.0, 1.0]");
            }
            if (duration_ms <= 0.0) {
                throw std::invalid_argument("Ramp: duration must be greater than zero");
            }
        }

        double ratio_at(double elapsed_ms) const {
            double progress = std::min(1.0, elapsed_ms / duration_ms);
            return start_ratio + (end_ratio - start_ratio) * progress;
        }

        void throttle(
            std::chrono::steady_clock::time_point start_time,
            std::chrono::steady_clock::time_point batch_start
        ) const {
            auto now = std::chrono::steady_clock::now();
            double elapsed_ms = std::chrono::duration<double, std::milli>(now - start_time).count();
            double ratio = ratio_at(elapsed_ms);

            if (ratio < 1.0) {
                auto batch_duration = now - batch_start;
                auto sleep_time = std::chrono::duration_cast<std::chrono::microseconds>(
                    batch_duration * (1.0 / ratio - 1.0));
                std::this_thread::sleep_for(sleep_time);
            }
        }
    };
};

#endif
