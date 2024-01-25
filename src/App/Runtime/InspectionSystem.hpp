#pragma once

#include "App/Runtime/ResourceRegistry.hpp"

namespace App
{
struct PhysicsTraceResultObject
{
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
    Red::WeakHandle<Red::entEntity> entity;
    uint64_t hash;
    bool resolved;
};

struct WorldNodeStreamingRequest
{
    bool streaming;
    uint64_t hash;
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
    Red::CompiledNodeInstanceSetupInfo* nodeSetup;
};

struct WorldNodeStaticSceneData
{
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
    Red::CompiledNodeInstanceSetupInfo* nodeSetup;
    Red::Vector3 scale;
    Core::Vector<Red::Box> boundingBoxes;
    bool isStaticMesh{false};
};

struct WorldNodeRuntimeSceneData
{
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
    Red::Vector4 position;
    Red::Quaternion orientation;
    Red::Vector3 scale;
    Red::Box boundingBox;
    float distance;
    uint64_t hash;
    bool resolved;
};

class InspectionSystem
    : public Red::IGameSystem
    , public INodeInstanceWatcher
{
public:
    static constexpr auto FrustumUpdateFreq = 0.1f;
    static constexpr auto FrustumMaxDistance = 120.0f;
    static constexpr auto RayCastingMaxDistance = 120.0f;

    InspectionSystem() = default;

    Red::CString ResolveResourcePath(uint64_t aResourceHash);

    WorldNodeStaticData ResolveSectorDataFromNodeID(uint64_t aNodeID);
    WorldNodeStaticData ResolveSectorDataFromNodeInstance(const Red::WeakHandle<Red::worldINodeInstance>& aNodeInstance);

    Red::CString ResolveNodeRefFromNodeHash(uint64_t aNodeID);
    uint64_t ComputeNodeRefHash(const Red::CString& aNodeRef);
    Red::EntityID ResolveCommunityIDFromEntityID(uint64_t aEntityID);

    Red::DynArray<Red::Handle<Red::IComponent>> GetComponents(const Red::WeakHandle<Red::Entity>& aEntity);
    Red::ResourceAsyncReference<> GetTemplatePath(const Red::WeakHandle<Red::Entity>& aEntity);
    PhysicsTraceResultObject GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace);

    WorldNodeRuntimeSceneData FindStreamedWorldNode(uint64_t aNodeID);
    Red::DynArray<WorldNodeRuntimeSceneData> GetStreamedWorldNodesInFrustum();
    Red::DynArray<WorldNodeRuntimeSceneData> GetStreamedWorldNodesInCrosshair();
    int32_t GetFrustumMaxDistance();

    Red::Vector4 GetStreamedNodePosition(const Red::Handle<Red::worldINodeInstance>& aNodeInstance);
    Red::Vector3 GetStreamedNodeScale(const Red::Handle<Red::worldINodeInstance>& aNodeInstance);
    bool SetNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance, bool aVisible);
    bool ToggleNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance);

    bool ApplyHighlightEffect(const Red::Handle<Red::ISerializable>& aObject,
                              const Red::Handle<Red::entRenderHighlightEvent>& aEffect);
    Red::Vector4 ProjectWorldPoint(const Red::Vector4& aPoint);

    Red::CName GetTypeName(const Red::WeakHandle<Red::ISerializable>& aInstace);
    bool IsInstanceOf(const Red::WeakHandle<Red::ISerializable>& aInstace, Red::CName aType);
    uint64_t GetObjectHash(const Red::WeakHandle<Red::ISerializable>& aInstace);

private:
    void OnWorldAttached(Red::world::RuntimeScene*) override;
    void OnAfterWorldDetach() override;
    void OnRegisterUpdates(Red::UpdateRegistrar* aRegistrar) override;

    void OnNodeStreamedIn(uint64_t aNodeHash,
                          Red::worldNode* aNodeDefinition,
                          Red::worldINodeInstance* aNodeInstance,
                          Red::CompiledNodeInstanceSetupInfo* aNodeSetup) override;
    void OnNodeStreamedOut(uint64_t aNodeHash) override;

    void UpdateStreamedNodes();
    void UpdateFrustumNodes();

    bool UpdateNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance, bool aToggle, bool aVisible);
    template<typename TRenderProxy>
    bool SetRenderProxyVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance, bool aToggle, bool aVisible);
    template<typename TRenderProxy>
    bool SetRenderProxyHighlightEffect(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
                                       const Red::Handle<Red::entRenderHighlightEvent>& aEffect);
    bool SetEntityHighlightEffect(const Red::Handle<Red::entEntity>& aEntity,
                                  const Red::Handle<Red::entRenderHighlightEvent>& aEffect);

    Core::SharedPtr<ResourceRegistry> m_resourceRegistry;
    Red::worldNodeInstanceRegistry* m_nodeRegistry;
    Red::gameICameraSystem* m_cameraSystem;

    std::shared_mutex m_pendingRequestsLock;
    Core::Map<uint64_t, WorldNodeStreamingRequest> m_pendingRequests;

    std::shared_mutex m_streamedNodesLock;
    Core::Map<uint64_t, WorldNodeStaticSceneData> m_streamedNodes;

    std::shared_mutex m_frustumNodesLock;
    Red::DynArray<WorldNodeRuntimeSceneData> m_frustumNodes;
    Red::DynArray<WorldNodeRuntimeSceneData> m_targetedNodes;

    float m_nodesUpdateDelay;
    volatile bool m_nodesUpdating;

    RTTI_IMPL_TYPEINFO(App::InspectionSystem);
    RTTI_IMPL_ALLOCATOR();
};
}

RTTI_DEFINE_CLASS(App::WorldNodeStaticData, {
    RTTI_PROPERTY(sectorHash);
    RTTI_PROPERTY(instanceIndex);
    RTTI_PROPERTY(instanceCount);
    RTTI_PROPERTY(nodeIndex);
    RTTI_PROPERTY(nodeCount);
    RTTI_PROPERTY(nodeType);
    RTTI_PROPERTY(nodeID);
    RTTI_PROPERTY(parentID);
});

RTTI_DEFINE_CLASS(App::WorldNodeRuntimeSceneData, {
    RTTI_PROPERTY(nodeInstance);
    RTTI_PROPERTY(nodeDefinition);
    RTTI_PROPERTY(position);
    RTTI_PROPERTY(orientation);
    RTTI_PROPERTY(boundingBox);
    RTTI_PROPERTY(distance);
    RTTI_PROPERTY(resolved);
    RTTI_PROPERTY(hash);
});

RTTI_DEFINE_CLASS(App::PhysicsTraceResultObject, {
    RTTI_PROPERTY(nodeInstance);
    RTTI_PROPERTY(nodeDefinition);
    RTTI_PROPERTY(entity);
    RTTI_PROPERTY(resolved);
    RTTI_PROPERTY(hash);
});

RTTI_DEFINE_CLASS(App::InspectionSystem, {
    RTTI_METHOD(ResolveResourcePath);
    RTTI_METHOD(ResolveSectorDataFromNodeID);
    RTTI_METHOD(ResolveSectorDataFromNodeInstance);
    RTTI_METHOD(ResolveNodeRefFromNodeHash);
    RTTI_METHOD(ComputeNodeRefHash);
    RTTI_METHOD(ResolveCommunityIDFromEntityID);
    RTTI_METHOD(FindStreamedWorldNode);
    RTTI_METHOD(GetStreamedWorldNodesInFrustum);
    RTTI_METHOD(GetStreamedWorldNodesInCrosshair);
    RTTI_METHOD(GetFrustumMaxDistance);
    RTTI_METHOD(GetStreamedNodePosition);
    RTTI_METHOD(GetStreamedNodeScale);
    RTTI_METHOD(SetNodeVisibility);
    RTTI_METHOD(ToggleNodeVisibility);
    RTTI_METHOD(ApplyHighlightEffect);
    RTTI_METHOD(GetComponents);
    RTTI_METHOD(GetTemplatePath);
    RTTI_METHOD(GetPhysicsTraceObject);
    RTTI_METHOD(ProjectWorldPoint);
    RTTI_METHOD(GetTypeName);
    RTTI_METHOD(IsInstanceOf);
    RTTI_METHOD(GetObjectHash);
});
