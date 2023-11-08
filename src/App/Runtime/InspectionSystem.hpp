#pragma once

#include "App/Runtime/ResourceRegistry.hpp"

namespace App
{
struct PhysicsObjectResult
{
    Red::WeakHandle<Red::entEntity> entity;
    Red::WeakHandle<Red::worldNode> node;
    uint64_t hash;
    bool resolved;
};

class InspectionSystem : public Red::IGameSystem
{
public:
    Red::CString ResolveResourcePath(uint64_t aResourceHash);
    WorldNodeStaticData ResolveNodeDataFromNodeID(uint64_t aNodeID);
    WorldNodeStaticData ResolveNodeDataFromNode(const Red::WeakHandle<Red::ISerializable>& aNode);
    Red::CString ResolveNodeRefFromNodeHash(uint64_t aNodeID);
    uint64_t ComputeNodeRefHash(const Red::CString& aNodeRef);
    Red::EntityID ResolveCommunityIDFromEntityID(uint64_t aEntityID);

    Red::DynArray<Red::Handle<Red::IComponent>> GetComponents(const Red::WeakHandle<Red::Entity>& aEntity);
    PhysicsObjectResult GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace);
    Red::WeakHandle<Red::worldNode> FindWorldNode(uint64_t aNodeID);
    Red::CName GetTypeName(const Red::WeakHandle<Red::ISerializable>& aInstace);
    bool IsInstanceOf(const Red::WeakHandle<Red::ISerializable>& aInstace, Red::CName aType);

private:
    void OnWorldAttached(Red::world::RuntimeScene*) override;
    void OnAfterWorldDetach() override;

    Core::SharedPtr<ResourceRegistry> m_resourceRegistry;
    Red::worldNodeInstanceRegistry* m_worldNodeRegistry;

    RTTI_IMPL_TYPEINFO(App::InspectionSystem);
    RTTI_IMPL_ALLOCATOR();
};
}

RTTI_DEFINE_CLASS(App::WorldNodeStaticData, {
    RTTI_PROPERTY(sectorHash);
    RTTI_PROPERTY(nodeIndex);
    RTTI_PROPERTY(nodeCount);
    RTTI_PROPERTY(nodeID);
    RTTI_PROPERTY(nodeType);
});

RTTI_DEFINE_CLASS(App::PhysicsObjectResult, {
    RTTI_PROPERTY(entity);
    RTTI_PROPERTY(node);
    RTTI_PROPERTY(resolved);
    RTTI_PROPERTY(hash);
});

RTTI_DEFINE_CLASS(App::InspectionSystem, {
    RTTI_METHOD(ResolveResourcePath);
    RTTI_METHOD(ResolveNodeDataFromNodeID);
    RTTI_METHOD(ResolveNodeDataFromNode);
    RTTI_METHOD(ResolveNodeRefFromNodeHash);
    RTTI_METHOD(ComputeNodeRefHash);
    RTTI_METHOD(ResolveCommunityIDFromEntityID);
    RTTI_METHOD(GetComponents);
    RTTI_METHOD(GetPhysicsTraceObject);
    RTTI_METHOD(FindWorldNode);
    RTTI_METHOD(GetTypeName);
    RTTI_METHOD(IsInstanceOf);
});
