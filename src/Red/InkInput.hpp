#pragma once

namespace Red
{
struct inkPointerHandler
{
    using AllocatorType = Memory::Ink_HitTestAllocator;

    virtual ~inkPointerHandler() = 0; // 00
    virtual void CollectWidgets(DynArray<Handle<inkWidget>>& aOut, Vector2& aPointerScreenPosition,
                                Vector2& aPointerWindowPosition, Vector2& aPointerSize) = 0; // 08
    virtual WeakHandle<inkVirtualWindow> GetActiveWindow() = 0;                              // 10

    void Reset(int32_t* aArea);
    void Override(const Red::SharedPtr<Red::inkPointerHandler>& aOverride, int32_t aIndex);

    static Red::SharedPtr<Red::inkPointerHandler> Create();
};
}

namespace Raw::inkPointerHandler
{
constexpr auto Create = Core::RawFunc<
    /* addr = */ Red::AddressLib::inkPointerHandler_Create,
    /* type = */ void (*)(Red::SharedPtr<Red::inkPointerHandler>& aOut)>();

constexpr auto Reset = Core::RawFunc<
    /* addr = */ Red::AddressLib::inkPointerHandler_Reset,
    /* type = */ void (*)(Red::inkPointerHandler* aHandler, int32_t* aArea)>();

constexpr auto Override = Core::RawFunc<
    /* addr = */ Red::AddressLib::inkPointerHandler_Override,
    /* type = */ void (*)(Red::inkPointerHandler* aHandler,
                          const Red::SharedPtr<Red::inkPointerHandler>& aOverride,
                          int32_t aIndex)>();
}
