#include "InkInput.hpp"

Red::SharedPtr<Red::inkPointerHandler> Red::inkPointerHandler::Create()
{
    Red::SharedPtr<Red::inkPointerHandler> handler;
    Raw::inkPointerHandler::Create(handler);
    return handler;
}

void Red::inkPointerHandler::Reset(int32_t* aArea)
{
    Raw::inkPointerHandler::Reset(this, aArea);
}

void Red::inkPointerHandler::Override(const Red::SharedPtr<Red::inkPointerHandler>& aOverride, int32_t aIndex)
{
    Raw::inkPointerHandler::Override(this, aOverride, aIndex);
}
