#ifndef TYPE_GENERATOR_H
#define TYPE_GENERATOR_H

#include <cstdint>

namespace Generator {
    struct BlockMetadata {
        uint64_t block_id;
        uint32_t compression;
    };
}

#endif

