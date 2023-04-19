#pragma once

#include "Addresses.hpp"

namespace Raw
{
constexpr auto LogChannel = Core::RawFunc<
    /* addr = */ Red::Addresses::LogChannel,
    /* type = */ void (*)(void*, Red::CStackFrame* aFrame, void*, void*)>();
}
