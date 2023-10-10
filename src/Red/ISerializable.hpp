#pragma once

#include "Addresses.hpp"

namespace Raw::ISerializable
{
constexpr auto CreateHandle = Core::RawFunc<
    /* addr = */ RED4ext::Addresses::Handle_ctor,
    /* type = */ void* (*)(Red::Handle<Red::ISerializable>& aHandle, Red::ISerializable* aObject)>();
}
