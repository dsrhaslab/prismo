#include <cstring>
#include <fstream>
#include <iostream>
#include <common/trace.h>
#include <common/operation.h>
#include <argparse/argparse.hpp>
#include <lib/komihash/komihash.h>

bool parse_line(const std::string& line, Trace::Record& record) {
    std::istringstream iss(line);
    std::string process;
    std::string block_id;
    char operation;

    iss >> record.timestamp
        >> record.pid
        >> process
        >> record.offset
        >> record.size
        >> operation
        >> record.major
        >> record.minor
        >> block_id;

    if (iss.fail()) {
        return false;
    }

    record.operation = Operation::operation_from_char(operation);
    record.process = komihash(process.data(), process.size(), 0);
    record.block_id = komihash(block_id.data(), block_id.size(), 0);

    return true;
}


int main(int argc, char** argv) {
    argparse::ArgumentParser program("Astroide");

    program.add_description("Parse .blkparse files into binary trace format.");

    program.add_argument("-i", "--input")
        .required()
        .help("specify the .blkparse input file");

    program.add_argument("-o", "--output")
        .required()
        .help("specify the output file");

    program.add_argument("-b", "--block-size")
        .default_value(static_cast<uint32_t>(512))
        .scan<'u', uint32_t>()
        .help("specify the block size");

    try {
        program.parse_args(argc, argv);
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << program;
        return 1;
    }

    std::string input = program.get<std::string>("--input");
    std::string output = program.get<std::string>("--output");
    uint32_t block_size = program.get<uint32_t>("--block-size");

    std::ifstream input_file(input);
    std::ofstream output_file(output, std::ios::binary);

    if (!input_file.is_open() || !output_file.is_open()) {
        std::cerr << "Failed to open files" << std::endl;
        return 1;
    }

    std::string line;
    Trace::Record record {};

    while (std::getline(input_file, line)) {
        if (line.empty()) {
            std::cerr << "Empty line" << std::endl;
            continue;
        }

        if (!parse_line(line, record)) {
            std::cerr << "Parse error: " << line << std::endl;
            continue;
        }

        record.size *= block_size;
        record.offset *= block_size;
        output_file.write(reinterpret_cast<const char*>(&record), sizeof(record));
    }

    input_file.close();
    output_file.close();

    return 0;
}
