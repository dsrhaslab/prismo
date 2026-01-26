#include <prismo/access/synthetic.h>

namespace Access {

    SequentialAccess::SequentialAccess()
        : Access(), current_offset(0) {}

    SequentialAccess::SequentialAccess(size_t _block_size, size_t _limit)
        : Access(_block_size, _limit), current_offset(0) {}

    uint64_t SequentialAccess::next_offset(void) {
        const uint64_t offset = current_offset;
        current_offset = static_cast<uint64_t>((current_offset + block_size) % limit);
        return offset;
    }

    void SequentialAccess::validate(void) const {
        Access::validate();
    }

    void from_json(const json& j, SequentialAccess& access_generator) {
        from_json(j, static_cast<Access&>(access_generator));
        access_generator.validate();
        access_generator.limit =
            access_generator.block_size *
            (access_generator.limit / access_generator.block_size);
    }
}
