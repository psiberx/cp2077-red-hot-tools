#pragma once

namespace Raw::EntityID
{
constexpr auto ToStringDEBUG = Core::RawFunc<
    /* addr = */ Red::AddressLib::EntityID_ToStringDEBUG,
    /* type = */ Red::CString* (*)(const Red::EntityID& aEntityID, Red::CString& aOut)>();
}
