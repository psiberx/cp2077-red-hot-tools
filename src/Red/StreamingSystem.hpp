#pragma once

namespace Raw::StreamingSystem
{
constexpr auto CollectNodeParallel = Core::RawFunc<
    /* addr = */ Red::AddressLib::StreamingSystem_CollectNodeParallel,
    /* type = */ void (*)(uint64_t a1, uint64_t a2, Red::Vector3* aPosition, uint64_t a4, uint32_t a5)>();
}


