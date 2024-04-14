#pragma once

namespace Raw::CBaseEngine
{
constexpr auto LoadScripts = Core::RawFunc<
    /* addr = */ Red::AddressLib::CBaseEngine_LoadScripts,
    /* type = */ bool (*)(Red::CBaseEngine& aEngine, Red::CString& aPath, uint64_t aTimestamp, uint64_t)>();

constexpr auto MainLoopTick = Core::RawFunc<
    /* addr = */ Red::AddressLib::CBaseEngine_MainLoopTick,
    /* type = */ bool (*)(Red::CBaseEngine& aEngine, float aDelta)>();
}
