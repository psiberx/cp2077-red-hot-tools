#pragma once

#include "App/UI/InkWidgetCollector.hpp"

namespace App
{
class InkInspector : public Red::IScriptable
{
public:
    InkInspector();

    Red::DynArray<InkLayerExtendedData> CollectInkLayers();
    InkWidgetCollectionData CollectHoveredWidgets();
    InkWidgetSpawnData GetWidgetSpawnInfo(const Red::Handle<Red::inkWidget>& aWidget);
    void EnablePointerInput();
    void DisablePointerInput();
    void TogglePointerInput();
    void EnsurePointerInput();
    Red::Vector2 GetPointerScreenPosition();
    Red::inkRectangle GetWidgetDrawRect(const Red::Handle<Red::inkWidget>& aWidget);

    static Red::Handle<InkInspector> Get()
    {
        return Red::MakeHandle<InkInspector>();
    }

private:
    Core::SharedPtr<InkWidgetCollector> m_collector;

    RTTI_IMPL_TYPEINFO(App::InkInspector);
    RTTI_IMPL_ALLOCATOR();
};
}

RTTI_DEFINE_CLASS(App::InkInspector, {
    RTTI_METHOD(CollectInkLayers);
    RTTI_METHOD(CollectHoveredWidgets);
    RTTI_METHOD(GetWidgetSpawnInfo);
    RTTI_METHOD(EnablePointerInput);
    RTTI_METHOD(DisablePointerInput);
    RTTI_METHOD(TogglePointerInput);
    RTTI_METHOD(EnsurePointerInput);
    RTTI_METHOD(GetPointerScreenPosition);
    RTTI_METHOD(GetWidgetDrawRect);
});

RTTI_EXPAND_CLASS(Red::ScriptGameInstance, {
    RTTI_METHOD_FQN(App::InkInspector::Get, "GetInkInspector");
});
