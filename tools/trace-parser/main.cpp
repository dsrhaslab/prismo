#include <fstream>
#include <iostream>
#include <cstdint>
#include <argparse/argparse.hpp>

struct TraceRecord {
    uint64_t timestamp;
    uint32_t pid;
    char     process[16];
    uint64_t offset;
    uint32_t size;
    char     rw;
    uint32_t major;
    uint32_t minor;
    uint8_t  hash[16];
};

int main(int argc, char** argv) {
    std::ifstream in(argv[1]);
    std::ofstream out(argv[2], std::ios::binary);

    if (!in || !out) {
        std::cerr << "Failed to open files\n";
        return 1;
    }

    std::string line;
    TraceRecord rec{};

    while (std::getline(in, line)) {
        if (line.empty())
            continue;

        if (!parse_line(line, rec)) {
            std::cerr << "Parse error: " << line << '\n';
            continue;
        }Include

        out.write(reinterpret_cast<const char*>(&rec), sizeof(rec));
    }

    return 0;
}
