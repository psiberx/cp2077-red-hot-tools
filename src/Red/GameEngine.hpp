#pragma once

#include "Addresses.hpp"

namespace Raw::CBaseEngine
{
constexpr auto LoadScripts = Core::RawFunc<
    /* addr = */ Red::Addresses::CBaseEngine_LoadScripts,
    /* type = */ bool (*)(Red::CBaseEngine& aEngine, Red::CString& aPath, uint64_t aTimestamp, uint64_t)>();

constexpr auto MainLoopTick = Core::RawFunc<
    /* addr = */ Red::Addresses::CBaseEngine_MainLoopTick,
    /* type = */ bool (*)(Red::CBaseEngine& aEngine, float aDelta)>();
}
