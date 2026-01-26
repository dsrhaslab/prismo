#ifndef ENGINE_CONFIG_H
#define ENGINE_CONFIG_H

#include <cstdint>
#include <fcntl.h>
#include <iostream>
#include <libaio.h>
#include <liburing.h>
#include <nlohmann/json.hpp>
#include <prismo/operation/type.h>
#include <prismo/generator/metadata.h>

using json = nlohmann::json;

namespace Engine {

    struct OpenFlags {
        int value;
    };

    struct AioConfig {
        size_t block_size;
        uint32_t entries;
    };

    struct UringConfig {
        size_t block_size;
        uint32_t entries;
        io_uring_params params{};
    };

    struct SpdkConfig {
        std::string bdev_name;
        std::string reactor_mask;
        std::string json_config_file;
        uint8_t spdk_threads;
        std::vector<uint32_t> pinned_cores;
    };

    struct MetricData {
        size_t size;
        uint64_t offset;
        int64_t start_timestamp;
        Generator::BlockMetadata metadata;
        Operation::OperationType operation_type;
    };

    struct UringUserData {
        int index;
        struct MetricData metric_data;
    };

    struct AioTask {
        void* buffer;
        uint32_t index;
        struct MetricData metric_data;
    };

    void from_json(const json& j, OpenFlags& config);
    void from_json(const json& j, AioConfig& config);
    void from_json(const json& j, UringConfig& config);
    void from_json(const json& j, SpdkConfig& config);

    std::vector<u_int32_t> get_pinned_cores(uint64_t mask);
};

#endif
