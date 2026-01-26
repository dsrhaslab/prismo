#ifndef TYPE_OPERATION_H
#define TYPE_OPERATION_H

#include <string>
#include <stdexcept>

namespace Operation {

    enum class OperationType {
        READ = 0,
        WRITE = 1,
        FSYNC = 2,
        FDATASYNC = 3,
        NOP = 4,
    };

    inline OperationType operation_from_str(std::string& operation) {
        if (operation == "read") {
            return OperationType::READ;
        } else if (operation == "write") {
            return OperationType::WRITE;
        } else if (operation == "fsync") {
            return OperationType::FSYNC;
        } else if (operation == "fdatasync") {
            return OperationType::FDATASYNC;
        } else if (operation == "nop") {
            return OperationType::NOP;
        } else {
            throw std::invalid_argument("operation_from_str: operation of type '" + operation + "' not recognized");
        }
    }
};

#endif