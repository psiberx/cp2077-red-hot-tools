#pragma once

#include "Red/Addresses.hpp"

namespace Red
{
struct FileHandle
{
    ~FileHandle();

    operator bool() const noexcept
    {
        return ptr;
    }

    uint64_t ptr; // 00
};

struct FileSystem
{
    virtual ~FileSystem() = 0;                                  // 00
    virtual FileHandle Open(CString aPath, uint8_t aFlags) = 0; // 08

    static FileSystem* Get();
};
}

namespace Raw::FileSystem
{
constexpr auto Instance = Core::RawPtr<
    /* addr = */ Red::Addresses::FileSystem_Instance,
    /* type = */ Red::FileSystem*>();

constexpr auto Close = Core::RawFunc<
    /* addr = */ Red::Addresses::FileSystem_Close,
    /* type = */ void (*)(Red::FileHandle* aHandle)>();
}
