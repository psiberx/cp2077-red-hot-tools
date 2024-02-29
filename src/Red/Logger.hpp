#pragma once

namespace Raw
{
constexpr auto LogChannel = Core::RawFunc<
    /* addr = */ Red::AddressLib::LogChannel,
    /* type = */ void (*)(void*, Red::CStackFrame* aFrame, void*, void*)>();
}
