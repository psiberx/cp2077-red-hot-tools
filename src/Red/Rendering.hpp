#pragma once

#include "Red/Addresses.hpp"

namespace Red
{
struct RenderProxy
{
    virtual ~RenderProxy() = 0;
};

struct HighlightParams
{
    bool seeThroughWalls; // 00
    uint8_t patternType;  // 01
    uint8_t fillIndex;    // 02
    uint8_t outlineIndex; // 03
    float opacity;        // 04
    bool forced;          // 08
};
}

namespace Raw::RenderProxy
{
using Flags = Core::OffsetPtr<0x23, uint8_t>;

inline bool IsVisible(Red::RenderProxy* aProxy)
{
    return (Flags::Ref(aProxy) & 6) == 6;
}

constexpr auto SetVisibility = Core::RawFunc<
    /* addr = */ 0x14019902C - Red::Addresses::ImageBase, // FIXME
    /* type = */ void (*)(Red::RenderProxy* aProxy, bool aVisible)>();

constexpr auto SetHighlightParams = Core::RawFunc<
    /* addr = */ 0x14099FD10 - Red::Addresses::ImageBase, // FIXME
    /* type = */ uint8_t (*)(Red::RenderProxy* aProxy, const Red::HighlightParams& aParams)>();
}
