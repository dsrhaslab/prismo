#include <prismo/access/synthetic.h>

namespace Access {

    ZipfianAccess::ZipfianAccess()
        : Access(), skew(0), distribution(0, 99, 0.9f) {}

    ZipfianAccess::ZipfianAccess(size_t _block_size, size_t _limit, float _skew)
        : Access(_block_size, _limit), skew(_skew), distribution(0, _limit, _skew) {}

    uint64_t ZipfianAccess::next_offset(void) {
        return static_cast<uint64_t>(distribution.nextValue() * block_size);
    }

    void ZipfianAccess::validate(void) const {
        Access::validate();
        if (skew <= 0 || skew >= 1) {
            throw std::invalid_argument("zipfian_validate: skew must belong to range [0; 1]");
        }
    }

    void from_json(const json& j, ZipfianAccess& access_generator) {
        from_json(j, static_cast<Access&>(access_generator));
        j.at("skew").get_to(access_generator.skew);
        access_generator.validate();

        access_generator.limit =
            access_generator.limit /
            access_generator.block_size - 1;

        access_generator.distribution.setParams(
            0,
            access_generator.limit,
            access_generator.skew
        );
    }
}