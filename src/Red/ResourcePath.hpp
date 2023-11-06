#pragma once

#include "Red/Addresses.hpp"
#include "Red/Strings.hpp"

namespace Raw::ResourcePath
{
constexpr auto Create = Core::RawFunc<
    /* addr = */ Red::Addresses::ResourcePath_Create,
    /* type = */ Red::ResourcePath* (*)(Red::ResourcePath* aOut, const Red::StringView* aPath)>();
}
