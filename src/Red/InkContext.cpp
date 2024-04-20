#include "InkContext.hpp"
#include "Red/InkWidget.hpp"

Red::inkWidgetContext::inkWidgetContext(Red::inkWidgetContext& aOther)
{
    Raw::inkWidgetContext::Clone(*this, aOther);
}

Red::inkWidgetContext::inkWidgetContext(Red::inkWidgetContext& aOther, Red::inkPointerHandler* aPointerHandler)
{
    Raw::inkWidgetContext::Clone(*this, aOther);
    pointerHandler = aPointerHandler;
}

void Red::inkWidgetContext::AddInteractiveWidget(const Red::WeakHandle<Red::inkWidget>& aWidget,
                                                 bool aVisible, bool aAffectsLayout)
{
    Raw::inkWidgetContext::AddWidget(*this, aWidget, aVisible, aAffectsLayout);
}

const Red::inkDrawContext* Red::inkDrawContext::Resolve(const RED4ext::Handle<RED4ext::inkWidget>& aWidget)
{
    Red::Handle<Red::inkWidget> parentWidget;

    {
        std::shared_lock _(aWidget->parentLock);
        parentWidget = aWidget->parentWidget.Lock();
    }

    if (parentWidget)
    {
        const auto& drawContexts = Raw::inkWidget::DrawContexts::Ref(parentWidget);
        for (const auto& drawContext : drawContexts)
        {
            if (drawContext.widget.instance == aWidget)
            {
                return &drawContext;
            }
        }
    }

    return nullptr;
}
