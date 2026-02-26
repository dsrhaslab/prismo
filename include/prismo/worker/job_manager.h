#ifndef PRISMO_WORKER_JOB_MANAGER_H
#define PRISMO_WORKER_JOB_MANAGER_H

#include <thread>
#include <vector>
#include <prismo/factory/factory.h>
#include <prismo/worker/consumer.h>
#include <prismo/worker/producer.h>

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
                jobs.resize(numjobs);
                threads.reserve(numjobs * 2);

                for (size_t i = 0; i < numjobs; i++) {
                    auto access =
                        Factory::get_access_generator(access_json);
                    auto operation =
                        Factory::get_operation_generator(operation_json);
                    auto content =
                        Factory::get_content_generator(generator_json);
                    auto compression =
                        Factory::get_compression_generator(generator_json);
                    auto barrier =
                        Factory::get_multiple_barrier(operation_json);
                    auto ramp =
                        Factory::get_ramp(job_json);
                    auto  metric =
                        Factory::get_metric(job_json);
                    auto logger =
                        Factory::get_logger(logging_json);
                    auto engine =
                        Factory::get_engine(
                            engine_json, std::move(metric), std::move(logger));

                    auto to_producer = std::make_shared<
                        moodycamel::ConcurrentQueue<Protocol::Packet*>>(
                        QUEUE_INITIAL_CAPACITY);

                    auto to_consumer = std::make_shared<
                        moodycamel::ConcurrentQueue<Protocol::Packet*>>(
                        QUEUE_INITIAL_CAPACITY);

                    init_queue_packet(*to_producer, block_size);

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
                }
            }

            void run_jobs(void) {
                for (size_t i = 0; i < numjobs; i++) {
                    threads.emplace_back(
                        &Producer::run,
                        jobs[i].producer.get(),
                        jobs[i].fd,
                        termination
                    );

                    threads.emplace_back(
                        &Consumer::run,
                        jobs[i].consumer.get()
                    );
                }

                for (auto& thread : threads) {
                    thread.join();
                }
            }

            void teardown(void) {
                for (size_t i = 0; i < numjobs; i++) {
                    Protocol::CloseRequest close_request{.fd = jobs[i].fd};
                    jobs[i].consumer->close(close_request);
                    destroy_queue_packet(*jobs[i].to_producer, QUEUE_INITIAL_CAPACITY);
                }
            }

            nlohmann::json collect_reports(void) {
                nlohmann::json final_report;
                final_report["jobs"] = nlohmann::json::array();

                for (size_t i = 0; i < numjobs; i++) {
                    nlohmann::json job_report = jobs[i].consumer->get_report();
                    job_report["job_id"] = i;
                    final_report["jobs"].push_back(job_report);
                }

                return final_report;
            }
    };
};

#endif
