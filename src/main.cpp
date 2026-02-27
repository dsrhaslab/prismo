#include <fstream>
#include <argparse/argparse.hpp>
#include <prismo/worker/job_manager.hpp>


int main(int argc, char** argv) {
    argparse::ArgumentParser program("prismo");

    program.add_description("Prismo I/O benchmarking tool.");

    program.add_argument("-c", "--config")
        .required()
        .help("specify the configuration file");

    program.add_argument("-l", "--logging")
        .flag()
        .help("enable debug logging");

    try {
        program.parse_args(argc, argv);
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << program;
        return 1;
    }

    if (program.get<bool>("--logging")) {
        spdlog::set_level(spdlog::level::debug);
        spdlog::info("Debug logging enabled");
    } else {
        spdlog::set_level(spdlog::level::info);
    }

    std::string config = program.get<std::string>("--config");
    spdlog::info("Loading configuration from: {}", config);

    std::ifstream config_file(config);

    if (!config_file.is_open()) {
        spdlog::error("Failed to open config file: {}", config);
        return 1;
    }

    nlohmann::json config_json = nlohmann::json::parse(config_file);
    config_file.close();
    spdlog::debug("Configuration parsed successfully");

    spdlog::info("Creating JobManager");
    Worker::JobManager manager(config_json);

    spdlog::info("Setup jobs phase");
    manager.setup_jobs();

    spdlog::info("Execution phase");
    manager.run_jobs();

    spdlog::info("Collecting reports from jobs");
    nlohmann::json report = manager.collect_reports();

    spdlog::info("Cleanup phase");
    manager.teardown();

    spdlog::info("Prismo execution completed successfully");
    std::cout << report.dump(2) << std::endl;

    return 0;
}