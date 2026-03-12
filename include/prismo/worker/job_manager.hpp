#ifndef PRISMO_WORKER_JOB_MANAGER_H
#define PRISMO_WORKER_JOB_MANAGER_H

#include <thread>
#include <vector>
#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <prismo/factory/factory.hpp>
#include <prismo/worker/consumer.hpp>
#include <prismo/worker/producer.hpp>

namespace Worker {

    struct Job {
        int fd;
        std::unique_ptr<Producer> producer;
        std::unique_ptr<Consumer> consumer;
        std::shared_ptr<moodycamel::ConcurrentQueue<std::unique_ptr<Protocol::Packet>>> to_producer;
        std::shared_ptr<moodycamel::ConcurrentQueue<std::unique_ptr<Protocol::Packet>>> to_consumer;
    };

    class JobManager {
        private:
            std::vector<Job> jobs;
            std::vector<std::thread> threads;

            size_t numjobs;
            size_t block_size;
            std::string filename;

            nlohmann::json job_json;
            nlohmann::json access_json;
            nlohmann::json operation_json;
            nlohmann::json content_json;
            nlohmann::json engine_json;
            nlohmann::json logging_json;

        public:
            JobManager(const nlohmann::json& config_json);

            void setup_jobs(void);

            void run_jobs(void);

            void teardown(void);

            nlohmann::json collect_reports(void);
    };
};

#endif
