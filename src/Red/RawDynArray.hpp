#pragma once

namespace Red
{
template<typename T>
struct RawDynArray
{
    T* entries;        // 00
    uint32_t capacity; // 08
    uint32_t size;     // 0C
};
RED4EXT_ASSERT_SIZE(RawDynArray<void*>, 0x10);
}
