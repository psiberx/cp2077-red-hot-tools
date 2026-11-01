#pragma once

namespace Raw::CBaseEngine
{
constexpr auto InvokeSCC = Core::RawFunc<
    /* addr = */ Red::AddressLib::CBaseEngine_InvokeSCC,
    /* type = */ bool (*)(Red::CString& aSourceDir, Red::CString& aBlobPath, uint8_t aProfile,
                          int64_t a4, int32_t a5, int32_t a6, Red::CString* aOutput)>();

constexpr auto LoadScripts = Core::RawFunc<
    /* addr = */ Red::AddressLib::CBaseEngine_LoadScripts,
    /* type = */ bool (*)(Red::CBaseEngine& aEngine, Red::CString& aPath, uint64_t aTimestamp, uint64_t)>();

constexpr auto MainLoopTick = Core::RawFunc<
    /* addr = */ Red::AddressLib::CBaseEngine_MainLoopTick,
    /* type = */ bool (*)(Red::CBaseEngine& aEngine, float aDelta)>();
}
