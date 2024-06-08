#pragma once

#include "App/Shared/ResourceRegistry.hpp"
#include "App/World/PhysicsTraceResult.hpp"
#include "App/World/WorldNodeRegistry.hpp"

namespace App
{
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
    Red::Box boundingBox;
    Core::Vector<Red::Box> testBoxes;
    bool isStaticMesh{false};
};

struct WorldNodeRuntimeSceneData
{
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
    Red::Box boundingBox;
    Red::Vector4 position;
    Red::Quaternion orientation;
    Red::Box testBox;
    float distance;
    bool frustum;
    uint64_t hash;
    bool resolved;
};

class WorldInspector
    : public Red::IGameSystem
    , public IWorldNodeInstanceWatcher
{
public:
    static constexpr auto FrustumUpdateFreq = 0.1f;
    static constexpr auto FrustumMinDistance = 120.0f;
    static constexpr auto FrustumMaxDistance = 999.0f;

    WorldInspector() = default;

    [[nodiscard]] float GetFrustumDistance() const;
    void SetFrustumDistance(float aDistance);
    [[nodiscard]] float GetTargetingDistance() const;
    void SetTargetingDistance(float aDistance);

    WorldNodeInstanceStaticData ResolveSectorDataFromNodeID(uint64_t aNodeID);
    WorldNodeInstanceStaticData ResolveSectorDataFromNodeInstance(const Red::WeakHandle<Red::worldINodeInstance>& aNodeInstance);

    Red::CString ResolveNodeRefFromNodeHash(uint64_t aNodeID);
    uint64_t ComputeNodeRefHash(const Red::CString& aNodeRef);
    Red::EntityID ResolveCommunityIDFromEntityID(uint64_t aEntityID);

    WorldNodeRuntimeSceneData FindStreamedNode(uint64_t aNodeID);
    Red::DynArray<WorldNodeRuntimeSceneData> GetStreamedNodesInFrustum();
    Red::DynArray<WorldNodeRuntimeSceneData> GetStreamedNodesInCrosshair();
    Red::Transform GetStreamedNodeTransform(const Red::WeakHandle<Red::worldINodeInstance>& aNode);

    bool ApplyHighlightEffect(const Red::Handle<Red::ISerializable>& aObject,
                              const Red::Handle<Red::entRenderHighlightEvent>& aEffect);
    bool SetNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance, bool aVisible);
    bool ToggleNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance);

    PhysicsTraceResultObject GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace);
    Red::Vector4 ProjectWorldPoint(const Red::Vector4& aPoint);

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

    Core::SharedPtr<WorldNodeRegistry> m_nodeRegistry;
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
    float m_frustumDistance{FrustumMinDistance};
    float m_targetingDistance{FrustumMinDistance};

    RTTI_IMPL_TYPEINFO(App::WorldInspector);
    RTTI_IMPL_ALLOCATOR();
};
}

RTTI_DEFINE_CLASS(App::WorldNodeInstanceStaticData, {
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

RTTI_DEFINE_CLASS(App::WorldInspector, {
    // RTTI_METHOD(GetStatus);
    // RTTI_METHOD(SetStatus);

    RTTI_METHOD(GetFrustumDistance);
    RTTI_METHOD(SetFrustumDistance);
    RTTI_METHOD(GetTargetingDistance);
    RTTI_METHOD(SetTargetingDistance);

    RTTI_METHOD(ResolveSectorDataFromNodeID);
    RTTI_METHOD(ResolveSectorDataFromNodeInstance);
    RTTI_METHOD(ResolveNodeRefFromNodeHash);
    RTTI_METHOD(ComputeNodeRefHash);
    RTTI_METHOD(ResolveCommunityIDFromEntityID);
    RTTI_METHOD(FindStreamedNode);
    RTTI_METHOD(GetStreamedNodesInFrustum);
    RTTI_METHOD(GetStreamedNodesInCrosshair);
    RTTI_METHOD(GetStreamedNodeTransform);

    RTTI_METHOD(ApplyHighlightEffect);
    RTTI_METHOD(SetNodeVisibility);
    RTTI_METHOD(ToggleNodeVisibility);

    RTTI_METHOD(GetPhysicsTraceObject);
    RTTI_METHOD(ProjectWorldPoint);
});
