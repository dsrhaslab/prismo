#include <prismo/access/synthetic.h>

namespace Access {

    void Access::validate(void) const {
        if (block_size == 0)
            throw std::invalid_argument("access_validate: block_size must be greater than zero");
        if (block_size > limit)
            throw std::invalid_argument("access_validate: block_size must be less than or equal to limit");
    }

    void from_json(const json& j, Access& access_generator) {
        j.at("block_size").get_to(access_generator.block_size);
        j.at("limit").get_to(access_generator.limit);
    }
}