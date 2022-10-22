#pragma once

#include "Addresses.hpp"

namespace Raw::ResourceBank
{
constexpr auto ForgetResource = Core::RawFunc<
    /* addr = */ Red::Addresses::ResourceBank_ForgetResource,
    /* type = */ uintptr_t (*)(uintptr_t aBank, Red::Handle<Red::CResource>& aResource,
                               const Red::ResourcePath aPath)>{};
}
