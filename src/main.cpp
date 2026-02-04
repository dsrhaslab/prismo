#include <fstream>
#include <argparse/argparse.hpp>
#include <prismo/parser/factory.h>
#include <prismo/worker/producer.h>
#include <prismo/worker/consumer.h>


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

    json config_json = json::parse(config_file);

    json job_json = config_json.at("job");
    json access_json = config_json.at("access");
    json operation_json = config_json.at("operation");
    json generator_json = config_json.at("generator");
    json engine_json = config_json.at("engine");
    json logging_json = config_json.at("logging");

    access_json.merge_patch(job_json);
    engine_json.merge_patch(job_json);
    generator_json.merge_patch(job_json);

    const size_t block_size = job_json.at("block_size").get<size_t>();
    const uint64_t iterations = job_json.at("iterations").get<uint64_t>();
    const std::string filename = job_json.at("filename").get<std::string>();

    Engine::OpenFlags open_flags = engine_json.at("openflags").get<Engine::OpenFlags>();

    std::cout << "Parse AccessGenerator" << std::endl;
    std::unique_ptr<Generator::AccessGenerator> access =
        Parser::get_access_generator(access_json);

    std::cout << "Parse OperationGenerator" << std::endl;
    std::unique_ptr<Generator::OperationGenerator> operation =
        Parser::get_operation_generator(operation_json);

    std::cout << "Parse ContentGenerator" << std::endl;
    std::unique_ptr<Generator::ContentGenerator> content =
        Parser::get_content_generator(generator_json);

    std::cout << "Parse CompressionGenerator" << std::endl;
    std::optional<Generator::CompressionGenerator> compression =
        Parser::get_compression_generator(generator_json);

    std::cout << "Parse MultipleBarrier" << std::endl;
    std::optional<Generator::MultipleBarrier> barrier =
        Parser::get_multiple_barrier(operation_json);

    std::cout << "Parse Metric" << std::endl;
    std::unique_ptr metric = Parser::get_metric(job_json);

    std::cout << "Parse Logger" << std::endl;
    std::unique_ptr<Logger::Logger> logger = Parser::get_logger(logging_json);

    std::cout << "Parse Engine" << std::endl;
    std::unique_ptr<Engine::Engine> engine =
        Parser::get_engine(engine_json, std::move(metric), std::move(logger));

    auto to_producer = std::make_shared<moodycamel::ConcurrentQueue<Protocol::Packet*>>(QUEUE_INITIAL_CAPACITY);
    auto to_consumer = std::make_shared<moodycamel::ConcurrentQueue<Protocol::Packet*>>(QUEUE_INITIAL_CAPACITY);

    Worker::init_queue_packet(
        *to_producer,
        block_size
    );

    Worker::Producer producer (
        std::move(access),
        std::move(operation),
        std::move(content),
        std::move(compression),
        std::move(barrier),
        to_producer,
        to_consumer
    );

    Worker::Consumer consumer (
        std::move(engine),
        to_producer,
        to_consumer
    );

    Protocol::OpenRequest open_request {
        .filename = filename,
        .flags = open_flags.value,
        .mode = 0666,
    };

    int fd = consumer.open(open_request);

    std::cout << "Parse Start Producer" << std::endl;
    std::thread producer_thread(&Worker::Producer::run, &producer, iterations, fd);

    std::cout << "Parse Start Consumer" << std::endl;
    std::thread consumer_thread(&Worker::Consumer::run, &consumer);

    producer_thread.join();
    consumer_thread.join();

    Protocol::CloseRequest close_request {
        .fd = fd
    };

    consumer.close(close_request);
    Worker::destroy_queue_packet(*to_producer, QUEUE_INITIAL_CAPACITY);
    config_file.close();

    return 0;
}