#include "InkInspector.hpp"
#include "Core/Facades/Container.hpp"
#include "Core/Facades/Log.hpp"
#include "Red/InkSystem.hpp"

App::InkInspector::InkInspector()
{
    m_collector = Core::Resolve<InkWidgetCollector>();
}

Red::DynArray<App::InkLayerExtendedData> App::InkInspector::CollectInkLayers()
{
    return m_collector->CollectLayers();
}

App::InkWidgetCollectionData App::InkInspector::CollectHoveredWidgets()
{
    return m_collector->CollectHoveredWidgets();
}

App::InkWidgetSpawnData App::InkInspector::GetWidgetSpawnInfo(const Red::Handle<Red::inkWidget>& aWidget)
{
    return m_collector->GetWidgetSpawnInfo(aWidget);
}

void App::InkInspector::EnablePointerInput()
{
    m_collector->TogglePointerInput(true);
}

void App::InkInspector::DisablePointerInput()
{
    m_collector->TogglePointerInput(false);
}

void App::InkInspector::TogglePointerInput()
{
    m_collector->TogglePointerInput();
}

void App::InkInspector::EnsurePointerInput()
{
    m_collector->EnsurePointerInput();
}

Red::Vector2 App::InkInspector::GetPointerScreenPosition()
{
    return Red::InkSystem::Get()->pointerScreenPosition;
}

Red::inkRectangle App::InkInspector::GetWidgetDrawRect(const Red::Handle<Red::inkWidget>& aWidget)
{
    Red::inkRectangle drawRect{};

    if (const auto drawContext = Red::inkDrawContext::Resolve(aWidget))
    {
        Raw::inkDrawArea::GetBoundingRect(drawContext->drawArea, drawRect, true);
    }

    return drawRect;
}
