#include <prismo/worker/job_manager.hpp>

namespace Worker {

    JobManager::JobManager(const nlohmann::json& config_json) {
        spdlog::debug("JobManager initialization started");

        job_json = config_json
            .value("job", nlohmann::json::object());
        access_json = config_json
            .value("access", nlohmann::json::object());
        operation_json = config_json
            .value("operation", nlohmann::json::object());
        content_json = config_json
            .value("content", nlohmann::json::object());
        engine_json = config_json
            .value("engine", nlohmann::json::object());
        logging_json = config_json
            .value("logger", nlohmann::json::object());

        access_json.merge_patch(job_json);
        engine_json.merge_patch(job_json);
        content_json.merge_patch(job_json);

        numjobs = job_json.value("numjobs", 1);
        block_size = job_json.value("block_size", 4096);
        filename = job_json.value("filename", "config.json");
    }

    void JobManager::setup_jobs(void) {
        spdlog::debug("Setting up {} job(s)", numjobs);
        jobs.resize(numjobs);
        threads.reserve(numjobs * 2);

        spdlog::debug("Parsing logger config (shared across all jobs)");
        auto shared_logger = Factory::get_logger(logging_json);

        for (size_t i = 0; i < numjobs; i++) {
            spdlog::debug("Setting up job {}", i);
            spdlog::debug("Parsing access generator config");

            access_json["worker_id"] = i;
            access_json["num_workers"] = numjobs;

            auto access =
                Factory::get_access_generator(access_json);

            spdlog::debug("Parsing operation generator config");
            auto operation =
                Factory::get_operation_generator(operation_json);

            spdlog::debug("Parsing content generator config");
            auto content =
                Factory::get_content_generator(content_json);

            spdlog::debug("Parsing compression generator config");
            auto compression =
                Factory::get_compression_generator(content_json);

            spdlog::debug("Parsing barrier config");
            auto barrier =
                Factory::get_multiple_barrier(operation_json);

            spdlog::debug("Parsing ramp config");
            auto ramp =
                Factory::get_ramp(job_json);

            spdlog::debug("Parsing termination config");
            auto termination =
                Factory::get_termination(job_json);

            spdlog::debug("Parsing open flags");
            auto open_flags =
                engine_json.at("open_flags").get<Engine::OpenFlags>();

            spdlog::debug("Parsing engine");
            auto engine =
                Factory::get_engine(engine_json, shared_logger);

            spdlog::debug(
                "Creating to_producer channel with initial capacity {}",
                Communication::QUEUE_INITIAL_CAPACITY);

            auto to_producer = Factory::get_channel(job_json);

            spdlog::debug(
                "Creating to_consumer channel with initial capacity {}",
                Communication::QUEUE_INITIAL_CAPACITY);

            auto to_consumer = Factory::get_channel(job_json);

            spdlog::debug(
                "Initializing packet pool for to_producer channel with block size {}",
                block_size);

            to_producer->init(block_size);

            spdlog::debug("Creating producer");
            auto producer = std::make_unique<Producer>(
                std::move(access),
                std::move(operation),
                std::move(content),
                std::move(barrier),
                std::move(compression),
                std::move(ramp),
                std::move(termination),
                to_producer,
                to_consumer
            );

            spdlog::debug("Creating consumer");
            auto consumer = std::make_unique<Consumer>(
                std::move(engine),
                to_producer,
                to_consumer
            );

            spdlog::debug("Creation open request");
            Protocol::OpenRequest open_request {
                .filename = filename,
                .flags = open_flags.value,
                .mode = 0666,
            };

            jobs[i].fd = consumer->open(open_request);
            jobs[i].producer = std::move(producer);
            jobs[i].consumer = std::move(consumer);
            jobs[i].to_consumer = std::move(to_consumer);
            jobs[i].to_producer = std::move(to_producer);

            spdlog::debug("Job {} setup complete: fd={}, filename={}", i,
                        jobs[i].fd, open_request.filename);
        }

        spdlog::debug("All {} jobs configured and ready", numjobs);
    }

    void JobManager::run_jobs(void) {
        spdlog::debug("Launching {} producer-consumer pair(s)", numjobs);

        for (size_t i = 0; i < numjobs; i++) {
            spdlog::debug("Starting producer thread for job {}", i);
            threads.emplace_back(
                &Producer::run,
                jobs[i].producer.get(),
                jobs[i].fd,
                i
            );

            spdlog::debug("Starting consumer thread for job {}", i);
            threads.emplace_back(
                &Consumer::run,
                jobs[i].consumer.get()
            );
        }

        spdlog::debug("All threads started, waiting for completion...");

        for (size_t i = 0; i < threads.size(); i++) {
            threads[i].join();
            spdlog::debug("Thread {} completed", i);
        }

        spdlog::debug("All threads completed");
    }

    void JobManager::teardown(void) {
        spdlog::debug("Tearing down {} job(s)", numjobs);

        for (size_t i = 0; i < numjobs; i++) {
            spdlog::debug("Closing job {}: fd={}", i, jobs[i].fd);

            Protocol::CloseRequest close_request{.fd = jobs[i].fd};
            jobs[i].consumer->close(close_request);

            spdlog::debug("Destroying packet pool for job {}", i);
            jobs[i].to_producer->destroy();

            spdlog::debug("Job {} teardown complete", i);
        }

        spdlog::debug("All jobs torn down successfully");
    }

    nlohmann::json JobManager::collect_reports(void) {
        spdlog::debug("Collecting reports from {} job(s)", numjobs);

        nlohmann::json final_report;
        final_report["jobs"] = nlohmann::json::array();

        for (size_t i = 0; i < numjobs; i++) {
            spdlog::debug("Collecting report for job {}", i);

            nlohmann::json job_report = jobs[i].consumer->get_statistics().to_json();
            job_report["job_id"] = i;
            final_report["jobs"].push_back(job_report);

            if (job_report.contains("total_operations")) {
                spdlog::debug("Job {}: {} operations, {} bytes, {:.2f}s runtime",
                    i,
                    job_report["total_operations"].get<uint64_t>(),
                    job_report["total_bytes"].get<uint64_t>(),
                    job_report["runtime_sec"].get<double>()
                );
            }
        }

        if (numjobs > 1) {
            spdlog::debug("Merging metrics from all {} jobs into 'all' entry", numjobs);

            Metric::Statistics merged;
            for (size_t i = 0; i < numjobs; i++) {
                merged.merge(jobs[i].consumer->get_statistics());
            }

            nlohmann::json all_report = merged.to_json();
            all_report["job_id"] = "all";
            final_report["jobs"].push_back(all_report);

            spdlog::debug("Merged 'all' entry added");
        }

        spdlog::debug("All reports collected successfully");
        return final_report;
    }
}
