#pragma once

namespace Red
{
struct InkPointerHandler
{
    virtual ~InkPointerHandler() = 0; // 00
    virtual void CollectWidgets(DynArray<Handle<inkWidget>>& aOut, Vector2& aPointerScreenPosition,
                                Vector2& aPointerWindowPosition, Vector2& aPointerSize) = 0; // 08
};
}

namespace Raw::inkLayer
{
constexpr auto GetPointerHandler = Core::RawVFunc<
    /* addr = */ 0x128,
    /* type = */ Red::InkPointerHandler* (Red::inkLayer::*)()>();
}

namespace Raw::inkWidget
{
constexpr auto Draw = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWidget_Draw,
    /* type = */ void (*)(Red::inkWidget*, void*)>();
}
