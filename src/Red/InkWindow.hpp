#pragma once

#include "Red/InkInput.hpp"

namespace Raw::inkWindow
{
using PointerHandler = Core::OffsetPtr<0x258, Red::SharedPtr<Red::inkPointerHandler>>;

constexpr auto Construct = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWindow_ctor,
    /* type = */ void (*)(Red::inkWindow* aWindow)>();

constexpr auto Destruct = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWindow_ctor,
    /* type = */ void (*)(Red::inkWindow* aWindow)>();

constexpr auto TogglePointerInput = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWindow_TogglePointerInput,
    /* type = */ void (*)(Red::inkWindow* aWindow, bool aEnabled)>();

constexpr auto IsPointerVisible = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWindow_IsPointerVisible,
    /* type = */ bool (*)(Red::inkWindow* aWindow)>();

constexpr auto SetPointerVisibility = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWindow_SetPointerVisibility,
    /* type = */ void (*)(Red::inkWindow* aWindow, bool aVisible)>();

constexpr auto SetPointerWidget = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWindow_SetPointerWidget,
    /* type = */ void (*)(Red::inkWindow* aWindow, const Red::Handle<Red::inkWidget>& aCursor)>();
}
