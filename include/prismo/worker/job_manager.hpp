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
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> to_producer;
        std::shared_ptr<moodycamel::ConcurrentQueue<Protocol::Packet*>> to_consumer;
    };

    class JobManager {
        private:
            std::vector<Job> jobs;
            std::vector<std::thread> threads;

            size_t numjobs;
            size_t block_size;
            std::string filename;
            Engine::OpenFlags open_flags;
            Termination termination;

            nlohmann::json job_json;
            nlohmann::json access_json;
            nlohmann::json operation_json;
            nlohmann::json generator_json;
            nlohmann::json engine_json;
            nlohmann::json logging_json;

        public:
            JobManager(const nlohmann::json& config_json) {
                spdlog::info("JobManager initialization started");

                job_json =config_json
                    .value("job", nlohmann::json::object());
                access_json = config_json
                    .value("access", nlohmann::json::object());
                operation_json = config_json
                    .value("operation", nlohmann::json::object());
                generator_json = config_json
                    .value("generator", nlohmann::json::object());
                engine_json = config_json
                    .value("engine", nlohmann::json::object());
                logging_json = config_json
                    .value("logging", nlohmann::json::object());

                access_json.merge_patch(job_json);
                engine_json.merge_patch(job_json);
                generator_json.merge_patch(job_json);

                numjobs = job_json.value("numjobs", 1);
                block_size = job_json.value("block_size", 4096);
                filename = job_json.value("filename", "config.json");
                open_flags = engine_json.at("openflags").get<Engine::OpenFlags>();
                termination = TerminationManager::parse(job_json.at("termination"));
            }

            void setup_jobs(void) {
                spdlog::info("Setting up {} job(s)", numjobs);
                jobs.resize(numjobs);
                threads.reserve(numjobs * 2);

                // Create logger once and share it across all engines (thread-safe)
                spdlog::debug("Parsing logger config (shared across all jobs)");
                auto shared_logger = Factory::get_logger(logging_json);

                for (size_t i = 0; i < numjobs; i++) {
                    spdlog::debug("Setting up job {}", i);
                    spdlog::debug("Parsing access generator config");
                    auto access =
                        Factory::get_access_generator(access_json);

                    spdlog::debug("Parsing operation generator config");
                    auto operation =
                        Factory::get_operation_generator(operation_json);

                    spdlog::debug("Parsing content generator config");
                    auto content =
                        Factory::get_content_generator(generator_json);

                    spdlog::debug("Parsing compression generator config");
                    auto compression =
                        Factory::get_compression_generator(generator_json);

                    spdlog::debug("Parsing barrier config");
                    auto barrier =
                        Factory::get_multiple_barrier(operation_json);

                    spdlog::debug("Parsing ramp config");
                    auto ramp =
                        Factory::get_ramp(job_json);

                    spdlog::debug("Parsing metric config");
                    auto  metric =
                        Factory::get_metric(job_json);

                    spdlog::debug("Creating engine with shared logger");
                    auto engine =
                        Factory::get_engine(
                            engine_json, std::move(metric), shared_logger);

                    spdlog::debug(
                        "Creating to_producer queue with initial capacity {}",
                        QUEUE_INITIAL_CAPACITY);

                    auto to_producer = std::make_shared<
                        moodycamel::ConcurrentQueue<Protocol::Packet*>>(
                        QUEUE_INITIAL_CAPACITY);

                    spdlog::debug(
                        "Creating to_consumer queue with initial capacity {}",
                        QUEUE_INITIAL_CAPACITY);

                    auto to_consumer = std::make_shared<
                        moodycamel::ConcurrentQueue<Protocol::Packet*>>(
                        QUEUE_INITIAL_CAPACITY);

                    spdlog::debug(
                        "Initializing packet pool for to_producer queue with block size {}",
                        block_size);

                    init_queue_packet(*to_producer, block_size);

                    spdlog::debug("Creating producer");
                    auto producer = std::make_unique<Producer>(
                        std::move(access),
                        std::move(operation),
                        std::move(content),
                        std::move(compression),
                        std::move(barrier),
                        std::move(ramp),
                        to_producer,
                        to_consumer
                    );

                    spdlog::debug("Creating consumer");
                    auto consumer = std::make_unique<Consumer>(
                        std::move(engine),
                        to_producer,
                        to_consumer
                    );

                    Protocol::OpenRequest open_request{
                        .filename = std::format("{}_worker_{}", filename, i),
                        .flags = open_flags.value,
                        .mode = 0666,
                    };

                    jobs[i].fd = consumer->open(open_request);
                    jobs[i].to_producer = to_producer;
                    jobs[i].to_consumer = to_consumer;
                    jobs[i].producer = std::move(producer);
                    jobs[i].consumer = std::move(consumer);

                    spdlog::info("Job {} setup complete: fd={}, filename={}", i,
                                jobs[i].fd, open_request.filename);
                }

                spdlog::info("All {} jobs configured and ready", numjobs);
            }

            void run_jobs(void) {
                spdlog::info("Launching {} producer-consumer pair(s)", numjobs);

                for (size_t i = 0; i < numjobs; i++) {
                    spdlog::debug("Starting producer thread for job {}", i);
                    threads.emplace_back(
                        &Producer::run,
                        jobs[i].producer.get(),
                        jobs[i].fd,
                        termination
                    );

                    spdlog::debug("Starting consumer thread for job {}", i);
                    threads.emplace_back(
                        &Consumer::run,
                        jobs[i].consumer.get()
                    );
                }

                spdlog::info("All threads started, waiting for completion...");

                for (size_t i = 0; i < threads.size(); i++) {
                    threads[i].join();
                    spdlog::debug("Thread {} completed", i);
                }

                spdlog::info("All threads completed");
            }

            void teardown(void) {
                spdlog::info("Tearing down {} job(s)", numjobs);

                for (size_t i = 0; i < numjobs; i++) {
                    spdlog::debug("Closing job {}: fd={}", i, jobs[i].fd);

                    Protocol::CloseRequest close_request{.fd = jobs[i].fd};
                    jobs[i].consumer->close(close_request);

                    spdlog::debug("Destroying packet pool for job {}", i);
                    destroy_queue_packet(*jobs[i].to_producer, QUEUE_INITIAL_CAPACITY);

                    spdlog::debug("Job {} teardown complete", i);
                }

                spdlog::info("All jobs torn down successfully");
            }

            nlohmann::json collect_reports(void) {
                spdlog::info("Collecting reports from {} job(s)", numjobs);

                nlohmann::json final_report;
                final_report["jobs"] = nlohmann::json::array();

                for (size_t i = 0; i < numjobs; i++) {
                    spdlog::debug("Collecting report for job {}", i);

                    nlohmann::json job_report = jobs[i].consumer->get_report();
                    job_report["job_id"] = i;
                    final_report["jobs"].push_back(job_report);

                    if (job_report.contains("total_operations")) {
                        spdlog::info("Job {}: {} operations, {} bytes, {:.2f}s runtime",
                            i,
                            job_report["total_operations"].get<uint64_t>(),
                            job_report["total_bytes"].get<uint64_t>(),
                            job_report["runtime_sec"].get<double>()
                        );
                    }
                }

                spdlog::info("All reports collected successfully");
                return final_report;
            }
    };
};

#endif
