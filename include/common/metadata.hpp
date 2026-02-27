#ifndef COMMON_METADATA_H
#define COMMON_METADATA_H

namespace Common {
    struct BlockMetadata {
        uint64_t block_id;
        uint32_t compression;
    };
};

#endif