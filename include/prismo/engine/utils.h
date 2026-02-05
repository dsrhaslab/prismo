#ifndef ENGINE_CONFIG_H
#define ENGINE_CONFIG_H

#include <common/operation.h>
#include <fcntl.h>
#include <libaio.h>
#include <liburing.h>
#include <prismo/generator/content/metadata.h>
#include <cstdint>
#include <iostream>
#include <nlohmann/json.hpp>

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
        uint64_t start_timestamp;
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
};  // namespace Engine

#endif
