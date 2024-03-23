#include "InkSystem.hpp"

Red::InkSystem* Red::InkSystem::Get()
{
    return Raw::inkSystem::Instance;
}

Red::InkLayerManager* Red::InkSystem::GetLayerManager()
{
    return layerManagers[0].instance;
}

const Red::DynArray<Red::Handle<Red::inkLayer>>& Red::InkSystem::GetLayers()
{
    return layerManagers[0]->layers;
}

const Red::DynArray<Red::Handle<Red::inkWidget>>& Red::InkSystem::GetHoverWidgets()
{
    return hoverWidgets;
}

const Red::WeakHandle<Red::inkISystemRequestsHandler>& Red::InkSystem::GetSystemRequestsHandler()
{
    return requestsHandler;
}

Red::inkISystemRequestsHandler* Red::InkSystem::GetSystemRequestsHandlerPtr()
{
    return requestsHandler.instance;
}
