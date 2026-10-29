#include "InkSystem.hpp"

Red::InkSystem* Red::InkSystem::Get()
{
    return Raw::inkSystem::Instance;
}

Red::InkLayerManager* Red::InkSystem::GetLayerManager() const
{
    return layerManagers[0].instance;
}

const Red::DynArray<Red::Handle<Red::inkLayer>>& Red::InkSystem::GetLayers() const
{
    return layerManagers[0]->layers;
}

RED4ext::Handle<RED4ext::inkLayer> Red::InkSystem::GetLayer(RED4ext::CName aLayerName) const
{
    auto it = std::find_if(layerManagers[0]->layers.Begin(), layerManagers[0]->layers.End(),
            [aLayerName](const Handle<inkLayer>& aLayer) -> bool
            {
               return aLayer->GetNativeType()->GetName() == aLayerName;
            });

    if (it == layerManagers[0]->layers.End())
        return {};

    return *it;
}

const Red::WeakHandle<Red::inkISystemRequestsHandler>& Red::InkSystem::GetSystemRequestsHandler() const
{
    return requestsHandler;
}

Red::inkISystemRequestsHandler* Red::InkSystem::GetSystemRequestsHandlerPtr() const
{
    return requestsHandler.instance;
}
