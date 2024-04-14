#pragma once

namespace Raw::ISerializable
{
constexpr auto CreateHandle = Core::RawFunc<
    /* addr = */ RED4ext::Detail::AddressHashes::Handle_ctor,
    /* type = */ void* (*)(Red::Handle<Red::ISerializable>& aHandle, Red::ISerializable* aObject)>();
}
