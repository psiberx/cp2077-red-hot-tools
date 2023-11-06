#pragma once

#include "Red/Addresses.hpp"

namespace Raw::EntityID
{
constexpr auto ToStringDEBUG = Core::RawFunc<
    /* addr = */ Red::Addresses::EntityID_ToStringDEBUG,
    /* type = */ Red::CString* (*)(const Red::EntityID& aEntityID, Red::CString&)>();
}
