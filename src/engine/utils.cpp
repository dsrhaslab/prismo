#include <prismo/engine/utils.h>

namespace Engine {

    static const std::unordered_map<std::string, int> flag_map = {
        {"O_CREAT", O_CREAT},
        {"O_TRUNC", O_TRUNC},
        {"O_APPEND", O_APPEND},
        {"O_RDONLY", O_RDONLY},
        {"O_WRONLY", O_WRONLY},
        {"O_RDWR", O_RDWR},
        {"O_SYNC", O_SYNC},
        {"O_DSYNC", O_DSYNC},
        {"O_RSYNC", O_RSYNC},
        {"O_DIRECT", O_DIRECT},
    };

    static const std::unordered_map<std::string, uint32_t> params_flag_map = {
        {"IORING_SETUP_IOPOLL", IORING_SETUP_IOPOLL},
        {"IORING_SETUP_SQPOLL", IORING_SETUP_SQPOLL},
        {"IORING_SETUP_SQ_AFF", IORING_SETUP_SQ_AFF},
        {"IORING_SETUP_CLAMP", IORING_SETUP_CLAMP},
        {"IORING_SETUP_CQSIZE", IORING_SETUP_CQSIZE},
        {"IORING_FEAT_NODROP", IORING_FEAT_NODROP},
        {"IORING_SETUP_SINGLE_ISSUER", IORING_SETUP_SINGLE_ISSUER},
        // {"IORING_SETUP_HYBRID_IOPOLL", IORING_SETUP_HYBRID_IOPOLL},
    };

    void from_json(const nlohmann::json& j, OpenFlags& config) {
        for (const auto& value : j) {
            auto it = flag_map.find(value);
            if (it != flag_map.end()) {
                config.value |= it->second;
            } else {
                throw std::invalid_argument("from_json: open flag value '" + value.get<std::string>() + "' not recognized");
            }
        }
    };

    void from_json(const nlohmann::json& j, AioConfig& config) {
        j.at("entries").get_to(config.entries);
        j.at("block_size").get_to(config.block_size);
    };

    void from_json(const nlohmann::json& j, UringConfig& config) {
        const nlohmann::json params_j = j.at("params");

        j.at("entries").get_to(config.entries);
        j.at("block_size").get_to(config.block_size);

        params_j.at("cq_entries").get_to(config.params.cq_entries);
        params_j.at("sq_thread_cpu").get_to(config.params.sq_thread_cpu);
        params_j.at("sq_thread_idle").get_to(config.params.sq_thread_idle);

        for (const auto& value : j.at("params").at("flags")) {
            auto it = params_flag_map.find(value);
            if (it != params_flag_map.end()) {
                config.params.flags |= it->second;
            } else {
                throw std::invalid_argument("from_json: uring params flag value '" + value.get<std::string>() + "' not recognized");
            }
        }
    };

    void from_json(const nlohmann::json& j, SpdkConfig& config) {
        j.at("bdev_name").get_to(config.bdev_name);
        j.at("reactor_mask").get_to(config.reactor_mask);
        j.at("json_config_file").get_to(config.json_config_file);
        j.at("spdk_threads").get_to(config.spdk_threads);

        char* endptr = nullptr;
        uint64_t mask = strtoull(config.reactor_mask.c_str(), &endptr, 0);

        if (*endptr != '\0') {
            throw std::invalid_argument("from_json: invalid reactor mask: " + config.reactor_mask);
        }

        std::vector<uint32_t> pinned_cores = get_pinned_cores(mask);
        config.pinned_cores.clear();
        for (const auto& core : pinned_cores) {
            config.pinned_cores.push_back(core);
        }

        if (config.pinned_cores.size() < 2) {
            throw std::invalid_argument("from_json: reactor mask must have at least 2 pinned cores");
        }

        for (auto a : config.pinned_cores) {
            std::cout << a << std::endl;
        }
    }

    std::vector<uint32_t> get_pinned_cores(uint64_t mask) {
        std::vector<uint32_t> cores;
        long max_cores = sysconf(_SC_NPROCESSORS_ONLN);
        for (uint32_t core = 0; core < max_cores; core++) {
            if (mask & (1ULL << core)) {
                cores.push_back(core);
            }
        }
        return cores;
    }
};
