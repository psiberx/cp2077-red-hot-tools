#pragma once

#include "Addresses.hpp"

namespace Raw::ISerializable
{
constexpr auto SetReference = Core::RawFunc<
    /* addr = */ Red::Addresses::ISerializable_SetReference,
    /* type = */ void (*)(Red::ISerializable& aObject, Red::Handle<Red::ISerializable>& aHandle)>();
}
