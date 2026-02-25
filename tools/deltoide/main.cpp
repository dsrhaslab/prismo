#include <data.h>
#include <normalizer.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <iostream>
#include <filesystem>
#include <argparse/argparse.hpp>

namespace fs = std::filesystem;

void analyse_file(
    const char* path,
    size_t block_size,
    DuplicationDB& duplication_db,
    CompressionDB& compression_db
) {
    uint64_t header = 0;
    ssize_t bytes_read = 0;
    std::vector<uint8_t> buffer(block_size);

    int fd = open(path, O_RDONLY);
    if (fd == -1) {
        throw std::runtime_error("open failed: " + std::string(path));
    }

    while ((bytes_read = read(fd, buffer.data(), block_size)) > 0) {
        std::memset(buffer.data() + bytes_read, 0, block_size - static_cast<size_t>(bytes_read));

        uint32_t compression = zstd_compress(buffer);
        std::memcpy(&header, buffer.data(), sizeof(header));

        update_compression_db(compression, compression_db);
        update_duplication_db(header, compression, duplication_db);
    }

    if (close(fd) == -1) {
        throw std::runtime_error("close failed");
    }
}

int main(int argc, char** argv) {
    argparse::ArgumentParser program("deltoid");

    program.add_description("Generate distributions from a dataset.");

    program.add_argument("-i", "--input")
        .required()
        .help("specify the dataset file, directory or block device");

    program.add_argument("-b", "--block-size")
        .default_value(static_cast<uint32_t>(4096))
        .help("specify the block size");

    program.add_argument("-c", "--compression")
        .flag()
        .help("shows the overall compression distribution");

    program.add_argument("-d", "--duplication")
        .flag()
        .help("shows the distribution of duplicated data with compression applied");

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
    std::vector<std::string> files;

    CompressionDB compression_db;
    DuplicationDB duplication_db;

    if (stat(dataset.c_str(), &st) != 0) {
        std::cerr << "stat failed: " << strerror(errno) << std::endl;
        return 1;
    }

    try {
        if (S_ISBLK(st.st_mode) || S_ISREG(st.st_mode)) {
            files.push_back(dataset);
        } else if (S_ISDIR(st.st_mode)) {
            for (const fs::directory_entry& entry :
                 fs::recursive_directory_iterator(dataset)) {
                files.push_back(entry.path());
            }
        } else {
            std::cerr << dataset
                      << " is not a file, a directory, or a block device"
                      << std::endl;
            return 1;
        }

        for (const auto& file : files) {
            std::cout << file << std::endl;
            analyse_file(file.c_str(), block_size, duplication_db, compression_db);
        }
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        return 1;
    }

    if (program["--compression"] == true) {
        normalize(compression_db);
        std::cout << static_cast<nlohmann::json>(compression_db).dump(4)
                  << std::endl;
    }

    if (program["--duplication"] == true) {
        normalize(duplication_db);
        std::cout << static_cast<nlohmann::json>(duplication_db).dump(4)
                  << std::endl;
    }

    return 0;
}