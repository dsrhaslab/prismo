#ifndef COMMON_OPERATION_H
#define COMMON_OPERATION_H

#include <stdexcept>
#include <string>

namespace Operation {

    enum class OperationType {
        READ = 0,
        WRITE = 1,
        FSYNC = 2,
        FDATASYNC = 3,
        NOP = 4,
    };

    inline OperationType operation_from_char(const char& operation) {
        return (operation == 'R')   ? OperationType::READ
               : (operation == 'W') ? OperationType::WRITE
               : (operation == 'S') ? OperationType::FSYNC
               : (operation == 'D') ? OperationType::FDATASYNC
               : (operation == 'N')
                   ? OperationType::NOP
                   : throw std::invalid_argument(
                         "operation_from_char: operation of type '" +
                         std::string(1, operation) + "' not recognized");
    };

    inline OperationType operation_from_str(const std::string& operation) {
        return (operation == "read")        ? OperationType::READ
               : (operation == "write")     ? OperationType::WRITE
               : (operation == "fsync")     ? OperationType::FSYNC
               : (operation == "fdatasync") ? OperationType::FDATASYNC
               : (operation == "nop")
                   ? OperationType::NOP
                   : throw std::invalid_argument(
                         "operation_from_str: operation of type '" + operation +
                         "' not recognized");
    };

    inline std::string operation_to_str(const OperationType& operation) {
        return (operation == OperationType::READ)        ? "read"
               : (operation == OperationType::WRITE)     ? "write"
               : (operation == OperationType::FSYNC)     ? "fsync"
               : (operation == OperationType::FDATASYNC) ? "fdatasync"
               : (operation == OperationType::NOP)
                   ? "nop"
                   : throw std::invalid_argument(
                         "operation_to_str: operation of type '" +
                         std::to_string(static_cast<int>(operation)) +
                         "' not recognized");
    };
};

#endif