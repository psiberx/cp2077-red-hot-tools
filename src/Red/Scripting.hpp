#pragma once

namespace Raw::ISerializable
{
constexpr auto Clone = Core::RawFunc<
    /* addr = */ Red::AddressLib::ISerializable_Clone,
    /* type = */ void* (*)(Red::Handle<Red::ISerializable>& aOut,
                           const Red::Handle<Red::ISerializable>& aObject)>();
}
