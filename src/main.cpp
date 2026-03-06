#include <fstream>
#include <argparse/argparse.hpp>
#include <prismo/worker/job_manager.hpp>


int main(int argc, char** argv) {
    argparse::ArgumentParser program("prismo");

    program.add_description("Prismo I/O benchmarking tool.");

    program.add_argument("-c", "--config")
        .required()
        .help("specify the configuration file");

    program.add_argument("-o", "--output")
        .default_value("-")
        .help("specify the output report file");

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
        spdlog::debug("Debug logging enabled");
    }

    std::string config = program.get<std::string>("--config");
    std::string output = program.get<std::string>("--output");

    spdlog::debug("Loading configuration from: {}", config);
    std::ifstream config_file(config);
    std::ofstream output_file;

    spdlog::debug("Opening output file: {}", output);
    std::ostream& output_stream = (output == "-")
        ? std::cout : (output_file.open(output), output_file);

    if (!config_file.is_open()) {
        spdlog::error("Failed to open config file: {}", config);
        return 1;
    }

    if (output != "-" && !output_file.is_open()) {
        spdlog::error("Failed to open output file: {}", output);
        return 1;
    }

    try {
        nlohmann::json config_json = nlohmann::json::parse(config_file);
        config_file.close();
        spdlog::debug("Configuration parsed successfully");

        spdlog::debug("Creating JobManager");
        Worker::JobManager manager(config_json);

        spdlog::debug("Setup jobs phase");
        manager.setup_jobs();

        spdlog::debug("Execution phase");
        manager.run_jobs();

        spdlog::debug("Collecting reports from jobs");
        nlohmann::json report = manager.collect_reports();

        spdlog::debug("Cleanup phase");
        manager.teardown();

        spdlog::debug("Writing report to output");
        output_stream << report.dump(2) << std::endl;

        spdlog::debug("Prismo execution completed successfully");

    } catch (const nlohmann::json::exception& e) {
        spdlog::error("Configuration error: {}", e.what());
        return 1;
    } catch (const std::invalid_argument& e) {
        spdlog::error("Invalid parameter: {}", e.what());
        return 1;
    } catch (const std::exception& e) {
        spdlog::error("Fatal error: {}", e.what());
        return 1;
    }

    return 0;
}