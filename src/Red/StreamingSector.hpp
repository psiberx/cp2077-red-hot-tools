#pragma once

namespace Raw::StreamingSector
{
constexpr auto Destruct = Core::RawFunc<
    /* addr = */ Red::AddressLib::StreamingSector_dtor,
    /* type = */ void (*)(Red::worldStreamingSector* aSector)>();

constexpr auto PostLoad = Core::RawFunc<
    /* addr = */ Red::AddressLib::StreamingSector_OnReady,
    /* type = */ void (*)(Red::worldStreamingSector* aSector, uint64_t a2)>();
}
