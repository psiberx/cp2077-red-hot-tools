#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"
#include "Red/InkLayer.hpp"

namespace App
{
class WidgetRegistry
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
protected:
    inline void OnBootstrap() override
    {
        Hook<Raw::inkWidget::Draw>(&OnWidgetDraw);
    }

    inline static bool IsLayerAffected(Red::inkWidget* aWidget)
    {
        return aWidget->layerProxy && !aWidget->layerProxy->layer.instance->isInteractive;
    }

    inline static bool IsWidgetAffected(Red::inkWidget* aWidget)
    {
        return !aWidget->isInteractive && !aWidget->GetNativeType()->IsA(Red::GetClass<Red::inkCacheWidget>());
    }

    inline static void OnWidgetDraw(Red::inkWidget* aWidget, void* a2)
    {
        bool isLayerAffected = IsLayerAffected(aWidget);
        bool isWidgetAffected = IsWidgetAffected(aWidget);

        if (isLayerAffected)
        {
            aWidget->layerProxy->layer.instance->isInteractive = true;
        }

        if (isWidgetAffected)
        {
            aWidget->isInteractive = true;
        }

        Raw::inkWidget::Draw(aWidget, a2);

        if (isWidgetAffected)
        {
            aWidget->isInteractive = false;
        }

        if (isLayerAffected)
        {
            aWidget->layerProxy->layer.instance->isInteractive = false;
        }
    }
};
}
