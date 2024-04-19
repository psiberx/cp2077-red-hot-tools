#include "InkContext.hpp"

Red::inkWidgetContext::inkWidgetContext(Red::inkWidgetContext& aOther)
{
    Raw::inkWidgetContext::Clone(*this, aOther);
}

Red::inkWidgetContext::inkWidgetContext(Red::inkWidgetContext& aOther, Red::inkPointerHandler* aPointerHandler)
{
    Raw::inkWidgetContext::Clone(*this, aOther);
    pointerHandler = aPointerHandler;
}

void Red::inkWidgetContext::AddWidget(const Red::WeakHandle<Red::inkWidget>& aWidget, bool aVisible,
                                      bool aAffectsLayout)
{
    Raw::inkWidgetContext::AddWidget(*this, aWidget, aVisible, aAffectsLayout);
}
