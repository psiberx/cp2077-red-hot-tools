#pragma once

#include "App/Runtime/ResourceRegistry.hpp"

namespace App
{
struct PhysicsObjectResult
{
    bool IsA(Red::CName aType);

    Red::WeakHandle<Red::ISerializable> object;
    Red::CName type;
    uint64_t hash;
    bool scriptable;
    bool resolved;
};

class InspectionSystem : public Red::IGameSystem
{
public:
    Red::CString ResolveResourcePath(uint64_t aResourceHash);
    Red::CString ResolveSectorPathFromNodeID(uint64_t aNodeID);
    Red::CString ResolveSectorPathFromNode(const Red::WeakHandle<Red::ISerializable>& aNode);
    Red::CString ResolveNodeRefFromNodeID(uint64_t aNodeID);
    Red::EntityID ResolveCommunityIDFromEntityID(Red::EntityID aEntityID);

    Red::DynArray<Red::Handle<Red::IComponent>> GetComponents(const Red::WeakHandle<Red::Entity>& aEntity);
    PhysicsObjectResult GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace);

private:
    void OnWorldAttached(Red::world::RuntimeScene*) override;
    void OnAfterWorldDetach() override;

    Core::SharedPtr<ResourceRegistry> m_registry;

    RTTI_IMPL_TYPEINFO(App::InspectionSystem);
    RTTI_IMPL_ALLOCATOR();
};
}

RTTI_DEFINE_CLASS(App::PhysicsObjectResult, {
    RTTI_PROPERTY(object);
    RTTI_PROPERTY(type);
    RTTI_PROPERTY(hash);
    RTTI_PROPERTY(scriptable);
    RTTI_PROPERTY(resolved);
    RTTI_METHOD(IsA);
});

RTTI_DEFINE_CLASS(App::InspectionSystem, {
    RTTI_METHOD(ResolveResourcePath);
    RTTI_METHOD(ResolveSectorPathFromNodeID);
    RTTI_METHOD(ResolveSectorPathFromNode);
    RTTI_METHOD(ResolveNodeRefFromNodeID);
    RTTI_METHOD(ResolveCommunityIDFromEntityID);
    RTTI_METHOD(GetComponents);
    RTTI_METHOD(GetPhysicsTraceObject);
});
