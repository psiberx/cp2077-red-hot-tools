#pragma once

#include "Red/Input.hpp"

namespace Red
{
struct InkLayerManager
{
    uint8_t unk00[0x38];               // 00
    DynArray<Handle<inkLayer>> layers; // 38
};
RED4EXT_ASSERT_OFFSET(InkLayerManager, layers, 0x38);

struct InkSystem
{
    static InkSystem* Get();

    InkLayerManager* GetLayerManager();
    const DynArray<Handle<inkLayer>>& GetLayers();
    const DynArray<Handle<inkWidget>>& GetHoverWidgets();
    const WeakHandle<inkISystemRequestsHandler>& GetSystemRequestsHandler();
    inkISystemRequestsHandler* GetSystemRequestsHandlerPtr();

    uint8_t unk00[0x2C0];                                  // 000
    Vector2 pointerScreenPosition;                         // 2C0
    Vector2 pointerWindowPosition;                         // 2C8
    uint8_t unk2D0[0x2E8 - 0x2D0];                         // 2FA
    WeakHandle<inkWidget> inputWidget;                     // 2E8
    KeyboardState keyboardState;                           // 2F8
    uint8_t unk2FA[0x328 - 0x2FA];                         // 2FA
    DynArray<Handle<inkWidget>> hoverWidgets;              // 328
    uint8_t unk330[0x368 - 0x338];                         // 330
    WeakHandle<inkISystemRequestsHandler> requestsHandler; // 368
    DynArray<SharedPtr<InkLayerManager>> layerManagers;    // 378
};
RED4EXT_ASSERT_OFFSET(InkSystem, pointerScreenPosition, 0x2C0);
RED4EXT_ASSERT_OFFSET(InkSystem, inputWidget, 0x2E8);
RED4EXT_ASSERT_OFFSET(InkSystem, keyboardState, 0x2F8);
RED4EXT_ASSERT_OFFSET(InkSystem, hoverWidgets, 0x328);
RED4EXT_ASSERT_OFFSET(InkSystem, requestsHandler, 0x368);
RED4EXT_ASSERT_OFFSET(InkSystem, layerManagers, 0x378);
}

namespace Raw::inkSystem
{
constexpr auto Instance = Core::RawPtr<
    /* addr = */ Red::AddressLib::InkSystem_Instance,
    /* type = */ Red::InkSystem*>();
}
