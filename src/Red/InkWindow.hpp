#pragma once

namespace Red
{
struct InkPointerHandler
{
    virtual ~InkPointerHandler() = 0; // 00
    virtual void CollectWidgets(DynArray<Handle<inkWidget>>& aOut, Vector2& aPointerScreenPosition,
                                Vector2& aPointerWindowPosition, Vector2& aPointerSize) = 0; // 08
    virtual WeakHandle<inkVirtualWindow> GetActiveWindow() = 0;                              // 10
};
}

namespace Raw::inkWindow
{
using PointerHandler = Core::OffsetPtr<0x258, Red::SharedPtr<Red::InkPointerHandler>>;

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
