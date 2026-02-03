#include <data.h>
#include <normalizer.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <iostream>
#include <filesystem>
#include <argparse/argparse.hpp>
#include <lib/komihash/komihash.h>

namespace fs = std::filesystem;

void analyse_file(
    const char* path,
    size_t block_size,
    DuplicationDB& duplication_db,
    CompressionDB& compression_db
) {
    ssize_t bytes_read = 0;
    std::vector<char> buffer(block_size);

    int fd = open(path, O_RDONLY);
    if (fd == -1) {
        throw std::runtime_error("open failed: " + std::string(path));
    }

    while ((bytes_read = read(fd, buffer.data(), block_size)) > 0) {
        std::memset(buffer.data() + bytes_read, 0, block_size - static_cast<size_t>(bytes_read));
        uint32_t compression = shannon_entropy(buffer.data(), block_size);
        uint64_t header = komihash(buffer.data(), block_size, 0);

        update_compression_db(compression, compression_db);
        update_duplication_db(header, compression, duplication_db);

        std::cout << "compression: " << compression << std::endl;
        std::cout << "header: " << header << std::endl;
    }

    if (close(fd) == -1) {
        throw std::runtime_error("close failed");
    }
}

int main(int argc, char** argv) {
    argparse::ArgumentParser program("deltoid");

    program.add_description("Generator distributions from dataset");

    program.add_argument("-i", "--input")
        .required()
        .help("specify the dataset directory or block device");

    program.add_argument("-b", "--block-size")
        .default_value(static_cast<uint32_t>(4096))
        .help("specify the block size");

    try {
        program.parse_args(argc, argv);
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << program;
        return 1;
    }

    std::string dataset = program.get<std::string>("--input");
    uint32_t block_size = program.get<uint32_t>("--block-size");

    struct stat st;
    CompressionDB compression_db;
    DuplicationDB duplication_db;

    if (stat(dataset.c_str(), &st) != 0) {
        std::cerr << "stat failed with errno: " << strerror(errno) << std::endl;
        return 1;
    }

    try {
        if (S_ISBLK(st.st_mode)) {
            analyse_file(
                dataset.c_str(),
                block_size,
                duplication_db,
                compression_db
            );
        } else if (S_ISDIR(st.st_mode)) {
            for (const fs::directory_entry& entry : fs::recursive_directory_iterator(dataset)) {
                std::cout << entry.path() << std::endl;
                if (fs::is_regular_file(entry)) {
                    analyse_file(
                        entry.path().c_str(),
                        block_size,
                        duplication_db,
                        compression_db
                    );
                }
            }
        } else {
            std::cerr << dataset << " is neither a directory nor a block device" << std::endl;
            return 1;
        }
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        return 1;
    }

    // normalize(compression_db);
    normalize(duplication_db);

    // json compression_j = compression_db;
    json duplication_j = duplication_db;

    // std::cout << compression_j.dump(4) << std::endl;
    std::cout << duplication_j.dump(4) << std::endl;

    return 0;
}