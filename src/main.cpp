#include <memory>
#include <iostream>
#include <iomanip>
#include <fstream>
#include <prismo/parser/parser.h>
#include <prismo/operation/type.h>
#include <prismo/operation/barrier.h>
#include <prismo/worker/utils.h>
#include <prismo/worker/producer.h>
#include <prismo/worker/consumer.h>


int main(int argc, char** argv) {

    if (argc < 2) {
        throw std::invalid_argument("main: invalid number of arguments");
    }

    std::ifstream config_file(argv[1]);
    json config_j = json::parse(config_file);

    json job_j = config_j.at("job");
    json access_j = config_j.at("access");
    json operation_j = config_j.at("operation");
    json barrier_j = operation_j.at("barrier");
    json generator_j = config_j.at("generator");
    json engine_j = config_j.at("engine");
    json logging_j = config_j.at("logging");

    access_j.merge_patch(job_j);
    engine_j.merge_patch(job_j);
    generator_j.merge_patch(job_j);

    const size_t block_size = job_j.at("block_size").get<size_t>();
    const uint64_t iterations = job_j.at("iterations").get<uint64_t>();
    const std::string filename = job_j.at("filename").get<std::string>();

    Engine::OpenFlags open_flags = engine_j.at("openflags").get<Engine::OpenFlags>();

    // std::cout << "Parse Access" << std::endl;
    std::unique_ptr<Access::Access> access = Parser::get_access(access_j);

    // std::cout << "Parse Operation" << std::endl;
    std::unique_ptr<Operation::Operation> operation = Parser::get_operation(operation_j);

    // std::cout << "Parse Generator" << std::endl;
    std::unique_ptr<Generator::Generator> generator = Parser::get_generator(generator_j);

    // std::cout << "Parse MultipleBarrier" << std::endl;
    std::unique_ptr<Operation::MultipleBarrier> barrier = Parser::get_multiple_barrier(barrier_j);

    // std::cout << "Parse Metric" << std::endl;
    std::unique_ptr metric = Parser::get_metric(job_j);

    // std::cout << "Parse Logger" << std::endl;
    std::unique_ptr<Logger::Logger> logger = Parser::get_logger(logging_j);

    // std::cout << "Parse Engine" << std::endl;
    std::unique_ptr<Engine::Engine> engine = Parser::get_engine(engine_j, std::move(metric), std::move(logger));

    auto to_producer = std::make_shared<moodycamel::ConcurrentQueue<Protocol::Packet*>>(QUEUE_INITIAL_CAPACITY);
    auto to_consumer = std::make_shared<moodycamel::ConcurrentQueue<Protocol::Packet*>>(QUEUE_INITIAL_CAPACITY);

    Worker::init_queue_packet(
        *to_producer,
        block_size
    );

    Worker::Producer producer (
        std::move(access),
        std::move(operation),
        std::move(generator),
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

    // std::cout << "Parse Start Producer" << std::endl;
    std::thread producer_thread(&Worker::Producer::run, &producer, iterations, fd);

    // std::cout << "Parse Start Consumer" << std::endl;
    std::thread consumer_thread(&Worker::Consumer::run, &consumer);

    producer_thread.join();
    consumer_thread.join();

    Protocol::CloseRequest close_request {
        .fd = fd
    };

    consumer.close(close_request);
    Worker::destroy_queue_packet(*to_producer, QUEUE_INITIAL_CAPACITY);
    config_file.close();

    // std::cout << "End" << std::endl;
    return 0;
}