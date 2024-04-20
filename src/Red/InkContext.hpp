#pragma once

#include "Red/InkInput.hpp"

namespace Red
{
struct inkWidgetContext
{
    inkWidgetContext() = default;
    inkWidgetContext(inkWidgetContext& aOther);
    inkWidgetContext(inkWidgetContext& aOther, inkPointerHandler* aPointerHandler);

    void AddInteractiveWidget(const Red::WeakHandle<Red::inkWidget>& aWidget,
                              bool aVisible = true, bool aAffectsLayout = false);

    uint64_t unk00;                    // 00
    inkPointerHandler* pointerHandler; // 08
    uint8_t unk10[0x70];               // 10
};
RED4EXT_ASSERT_SIZE(inkWidgetContext, 0x80);
RED4EXT_ASSERT_OFFSET(inkWidgetContext, pointerHandler, 0x08);
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
