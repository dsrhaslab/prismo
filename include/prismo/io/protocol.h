#ifndef IO_PROTOCOL_H
#define IO_PROTOCOL_H

#include <cstddef>
#include <fcntl.h>
#include <cstdint>
#include <prismo/generator/content/metadata.h>

namespace Protocol {

    struct OpenRequest {
        std::string filename;
        int flags;
        mode_t mode;
    };

    struct CloseRequest {
        int fd;
    };

    struct CommonRequest {
        int fd;
        size_t size;
        uint64_t offset;
        uint8_t* buffer;
        Generator::BlockMetadata metadata;
        Operation::OperationType operation;
    };

    struct Packet {
        bool isShutDown;
        CommonRequest request;
    };
}

#endif