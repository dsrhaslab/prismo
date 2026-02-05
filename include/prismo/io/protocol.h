#ifndef IO_PROTOCOL_H
#define IO_PROTOCOL_H

#include <fcntl.h>
#include <prismo/generator/content/metadata.h>
#include <cstddef>
#include <cstdint>

namespace Protocol {

    struct OpenRequest {
        std::string filename;
        int flags;
        mode_t mode;
    };

    struct CloseRequest {
        int fd;
    };

    struct IORequest {
        int fd;
        size_t size;
        uint64_t offset;
        uint8_t* buffer;
        Generator::BlockMetadata metadata;
        Operation::OperationType operation;
    };

    struct Packet {
        bool isShutDown;
        IORequest request;
    };
}  // namespace Protocol

#endif