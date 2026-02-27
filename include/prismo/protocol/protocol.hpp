#ifndef PRISMO_PROTOCOL_PROTOCOL_H
#define PRISMO_PROTOCOL_PROTOCOL_H

#include <cstddef>
#include <fcntl.h>
#include <cstdint>
#include <common/metadata.hpp>
#include <common/operation.hpp>

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
        Common::BlockMetadata metadata;
        Operation::OperationType operation;
    };

    struct Packet {
        bool isShutDown;
        IORequest request;
    };
}

#endif