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
    static InkSystem* Get(bool aCompatMode = false);

    [[nodiscard]] InkLayerManager* GetLayerManager() const;
    [[nodiscard]] const DynArray<Handle<inkLayer>>& GetLayers() const;
    [[nodiscard]] Handle<inkLayer> GetLayer(CName aLayerName) const;

    template<class T>
    requires std::is_base_of_v<inkLayer, T>
    [[nodiscard]] Handle<T> GetLayer() const
    {
        auto layer = GetLayer(T::NAME);

        if (!layer)
            return {};

        return *reinterpret_cast<Handle<T>*>(&layer);
    }

    [[nodiscard]] const WeakHandle<inkISystemRequestsHandler>& GetSystemRequestsHandler() const;
    [[nodiscard]] inkISystemRequestsHandler* GetSystemRequestsHandlerPtr() const;

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
    WeakPtr<InkLayerManager> activeManager;                // 388
    WeakHandle<inkLayer> activeLayer;                      // 398
    bool isPreGame;                                        // 3A8
};
RED4EXT_ASSERT_OFFSET(InkSystem, pointerScreenPosition, 0x2C0);
RED4EXT_ASSERT_OFFSET(InkSystem, inputWidget, 0x2E8);
RED4EXT_ASSERT_OFFSET(InkSystem, keyboardState, 0x2F8);
RED4EXT_ASSERT_OFFSET(InkSystem, hoverWidgets, 0x328);
RED4EXT_ASSERT_OFFSET(InkSystem, requestsHandler, 0x368);
RED4EXT_ASSERT_OFFSET(InkSystem, layerManagers, 0x378);
RED4EXT_ASSERT_OFFSET(InkSystem, activeManager, 0x388);
RED4EXT_ASSERT_OFFSET(InkSystem, activeLayer, 0x398);
}

namespace Raw::inkSystem
{
constexpr auto Instance = Core::RawPtr<
    /* addr = */ Red::AddressLib::InkSystem_Instance,
    /* type = */ Red::InkSystem*>();

constexpr auto Instance_Pre212a = Core::RawPtr<
    /* addr = */ Red::AddressLib::InkSystem_Instance_Pre212a,
    /* type = */ Red::InkSystem*>();
}
