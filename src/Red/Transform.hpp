#pragma once

#include "Addresses.hpp"

namespace Raw::Transform
{
constexpr auto ApplyToBox = Core::RawFunc<
    /* addr = */ Red::Addresses::Transform_ApplyToBox,
    /* type = */ void* (*)(const Red::Transform& aTransform, Red::Box& aOut, const Red::Box& aBox)>();
}
