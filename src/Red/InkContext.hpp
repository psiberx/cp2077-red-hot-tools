#pragma once

#include "Red/InkInput.hpp"

namespace Red
{
struct inkWidgetContext
{
    inkWidgetContext() = default;
    inkWidgetContext(inkWidgetContext& aOther);
    inkWidgetContext(inkWidgetContext& aOther, inkPointerHandler* aPointerHandler);

    void AddWidget(const Red::WeakHandle<Red::inkWidget>& aWidget, bool aVisible = true, bool aAffectsLayout = false);

    uint64_t unk00;
    inkPointerHandler* pointerHandler;
    uint8_t unk10[0x70];
};
}

namespace Raw::inkWidgetContext
{
constexpr auto Clone = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWidgetContext_Clone,
    /* type = */ void (*)(Red::inkWidgetContext& aContext, const Red::inkWidgetContext& aFrom)>();

constexpr auto AddWidget = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWidgetContext_AddWidget,
    /* type = */ void (*)(Red::inkWidgetContext& aContext, const Red::WeakHandle<Red::inkWidget>& aWidget,
                          bool aVisible, bool aAffectsLayoutWhenHidden)>();
}
