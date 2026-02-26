#include <fstream>
#include <argparse/argparse.hpp>
#include <prismo/worker/job_manager.h>


int main(int argc, char** argv) {
    argparse::ArgumentParser program("prismo");

    program.add_description("Prismo I/O benchmarking tool.");

    program.add_argument("-c", "--config")
        .required()
        .help("specify the configuration file");

    try {
        program.parse_args(argc, argv);
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << program;
        return 1;
    }

    std::string config = program.get<std::string>("--config");
    std::ifstream config_file(config);

    if (!config_file.is_open()) {
        std::cerr << "Failed to open file: " << config << std::endl;
        return 1;
    }

    nlohmann::json config_json = nlohmann::json::parse(config_file);
    config_file.close();

    Worker::JobManager manager(config_json);
    manager.setup_jobs();
    manager.run_jobs();
    manager.teardown();

    nlohmann::json report = manager.collect_reports();
    std::cout << report.dump(2) << std::endl;

    return 0;
}