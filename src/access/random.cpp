#include <prismo/access/synthetic.h>

namespace Access {

    RandomAccess::RandomAccess()
        : Access(), distribution() {}

    RandomAccess::RandomAccess(size_t _block_size, size_t _limit)
        : Access(_block_size, _limit), distribution(_block_size, _limit) {}

    uint64_t RandomAccess::next_offset(void) {
        return static_cast<uint64_t>(distribution.nextValue() * block_size);
    }

    void RandomAccess::validate(void) const {
        Access::validate();
    }

    void from_json(const json& j, RandomAccess& access_generator) {
        from_json(j, static_cast<Access&>(access_generator));
        access_generator.validate();
        access_generator.limit = access_generator.limit / access_generator.block_size - 1;
        access_generator.distribution.setParams(0, access_generator.limit);
    }
}
