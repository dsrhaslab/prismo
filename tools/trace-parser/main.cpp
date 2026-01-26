#include <cstring>
#include <fstream>
#include <iostream>
#include <common/trace.h>
#include <argparse/argparse.hpp>


bool parse_line(const std::string& line, TraceRecord& record) {
    std::istringstream iss(line);
    std::string process;
    std::string hash;

    iss >> record.timestamp
        >> record.pid
        >> process
        >> record.offset
        >> record.size
        >> record.rw
        >> record.major
        >> record.minor
        >> hash;

    if (iss.fail()) {
        return false;
    }

    std::memset(record.hash, 0, sizeof(record.hash));
    std::memset(record.process, 0, sizeof(record.process));

    std::memcpy(record.hash, hash.c_str(), sizeof(record.hash) - 1);
    std::memcpy(record.process, process.c_str(), sizeof(record.process) - 1);

    return true;
}


int main(int argc, char** argv) {
    argparse::ArgumentParser program("trace-parser");

    program.add_argument("-i", "--input")
        .required()
        .help("specify the .blkparse input file.");

    program.add_argument("-o", "--output")
        .required()
        .help("specify the output file.");

    try {
        program.parse_args(argc, argv);
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << program;
        return 1;
    }

    std::string input = program.get<std::string>("--input");
    std::string output = program.get<std::string>("--output");

    std::ifstream input_file(input);
    std::ofstream output_file(output, std::ios::binary);

    if (!input_file.is_open() || !output_file.is_open()) {
        std::cerr << "Failed to open files" << std::endl;
        return 1;
    }

    std::string line;
    TraceRecord record {};

    while (std::getline(input_file, line)) {
        if (line.empty()) {
            std::cerr << "Empty line" << std::endl;
            continue;
        }

        if (!parse_line(line, record)) {
            std::cerr << "Parse error: " << line << std::endl;
            continue;
        }

        output_file.write(reinterpret_cast<const char*>(&record), sizeof(record));
    }

    return 0;
}
