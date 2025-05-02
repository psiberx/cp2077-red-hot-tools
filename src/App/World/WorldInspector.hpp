#pragma once

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

struct WorldNodeStaticActorData
{
    Red::Vector4 position;
    Red::Quaternion orientation;
    Red::Box boundingBox;
    Red::Box testBox;
};

struct WorldNodeStaticSceneData
{
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
    Red::Vector4 position;
    Red::Quaternion orientation;
    Red::Vector3 scale;
    bool interior;
    Core::Vector<WorldNodeStaticActorData> actors;
    bool isTargetable{false};
};

struct WorldNodeRuntimeSceneData
{
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
    Red::Vector4 position;
    Red::Quaternion orientation;
    Red::Vector3 scale;
    Red::Box boundingBox;
    Red::Box testBox;
    int32_t actorIndex;
    uint32_t actorCount;
    float distance;
    bool interior;
    bool enabled;
    uint64_t hash;
    bool resolved;
};

struct WorldNodeRuntimeGeometryData
{
    inline Red::Transform& AsTransform()
    {
        return *reinterpret_cast<Red::Transform*>(&position);
    }

    Red::Vector4 position;
    Red::Quaternion orientation;
    Red::Vector3 scale;
    Red::Box boundingBox;
};

struct WorldCommunityEntryData : WorldCommunityStaticData
{
    int32_t entryIndex;
    uint32_t entryCount;
    Red::CName entryName;
    Red::CName entryPhase;
};

class WorldInspector
    : public Red::IGameSystem
    , public IWorldNodeInstanceWatcher
{
public:
    static constexpr auto FrustumUpdateFreq = 1.0f / 30;
    static constexpr auto FrustumMinDistance = 120.0f;
    static constexpr auto FrustumMaxDistance = 999.0f;
    static constexpr auto TargetingMinDistance = 2.0f;

    WorldInspector() = default;

    [[nodiscard]] bool IsReady() const;
    [[nodiscard]] float GetFrustumDistance() const;
    void SetFrustumDistance(float aDistance);
    [[nodiscard]] float GetTargetingDistance() const;
    void SetTargetingDistance(float aDistance);
    [[nodiscard]] bool IsDiscoverMode() const;
    void SetDiscoverMode(bool aEnabled);

    WorldNodeInstanceStaticData ResolveSectorDataFromNodeID(uint64_t aNodeID);
    WorldNodeInstanceStaticData ResolveSectorDataFromNodeInstance(const Red::WeakHandle<Red::worldINodeInstance>& aNodeInstance);

    Red::CString ResolveNodeRefFromNodeHash(uint64_t aNodeID);
    uint64_t ComputeNodeRefHash(const Red::CString& aNodeRef);
    Red::EntityID ResolveCommunityIDFromEntityID(uint64_t aEntityID);
    WorldCommunityEntryData ResolveCommunityEntryDataFromEntityID(uint64_t aEntityID);

    WorldNodeRuntimeSceneData FindStreamedNode(uint64_t aNodeID);
    Red::DynArray<WorldNodeRuntimeSceneData> GetStreamedNodesInFrustum();
    Red::DynArray<WorldNodeRuntimeSceneData> GetStreamedNodesInCrosshair();
    WorldNodeRuntimeGeometryData GetStreamedNodeGeometry(const Red::WeakHandle<Red::worldINodeInstance>& aNode);

    bool ApplyHighlightEffect(const Red::Handle<Red::ISerializable>& aObject,
                              const Red::Handle<Red::entRenderHighlightEvent>& aEffect);

    bool SetNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance, bool aVisible);
    bool ToggleNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance);
    [[nodiscard]] bool GetNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance) const;

    PhysicsTraceResultObject GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace);
    Red::Box GetPhysicsProxyBoundingBox(uint32_t aProxyID, int32_t aActorIndex, int32_t aShapeIndex);
    PhysicsTraceResulGeometry GetPhysicsProxyGeometry(uint32_t aProxyID, int32_t aActorIndex, int32_t aShapeIndex);
    PhysicsTraceResulGeometry GetPhysicsObjectGeometry(const Red::Handle<Red::ISerializable>& aObject, int32_t aActorIndex, int32_t aShapeIndex);
    Red::Vector4 ProjectWorldPoint(const Red::Vector4& aPoint);
    Red::Vector4 GetFrustumNearPlane();

private:
    void OnWorldAttached(Red::world::RuntimeScene*) override;
    void OnAfterWorldDetach() override;
    void OnRegisterUpdates(Red::UpdateRegistrar* aRegistrar) override;
    void OnGamePrepared() override;

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
    bool GetRenderProxyVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance) const;
    template<typename TRenderProxy>
    bool GetRenderProxyVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance) const;
    template<typename TRenderProxy>
    bool SetRenderProxyHighlightEffect(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
                                       const Red::Handle<Red::entRenderHighlightEvent>& aEffect);
    bool SetEntityHighlightEffect(const Red::Handle<Red::entEntity>& aEntity,
                                  const Red::Handle<Red::entRenderHighlightEvent>& aEffect) const;

    Core::SharedPtr<WorldNodeRegistry> m_nodeRegistry;
    Red::gameICameraSystem* m_cameraSystem;

    std::shared_mutex m_pendingRequestsLock;
    Core::Map<uint64_t, WorldNodeStreamingRequest> m_pendingRequests;

    std::shared_mutex m_streamedNodesLock;
    Core::Map<uint64_t, WorldNodeStaticSceneData> m_streamedNodes;

    std::shared_mutex m_frustumNodesLock;
    Red::DynArray<WorldNodeRuntimeSceneData> m_frustumNodes;
    Red::DynArray<WorldNodeRuntimeSceneData> m_targetedNodes;

    bool m_ready{false};
    bool m_discoverMode{false};
    float m_nodesUpdateDelay{0.0};
    volatile bool m_nodesUpdating{false};
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
    RTTI_PROPERTY(debugName);
    RTTI_PROPERTY(interior);
});

RTTI_DEFINE_CLASS(App::WorldNodeRuntimeSceneData, {
    RTTI_PROPERTY(nodeInstance);
    RTTI_PROPERTY(nodeDefinition);
    RTTI_PROPERTY(position);
    RTTI_PROPERTY(orientation);
    RTTI_PROPERTY(scale);
    RTTI_PROPERTY(boundingBox);
    RTTI_PROPERTY(testBox);
    RTTI_PROPERTY(actorIndex);
    RTTI_PROPERTY(actorCount);
    RTTI_PROPERTY(distance);
    RTTI_PROPERTY(interior);
    RTTI_PROPERTY(enabled);
    RTTI_PROPERTY(hash);
    RTTI_PROPERTY(resolved);
});

RTTI_DEFINE_CLASS(App::WorldNodeRuntimeGeometryData, {
    RTTI_PROPERTY(position);
    RTTI_PROPERTY(orientation);
    RTTI_PROPERTY(scale);
    RTTI_PROPERTY(boundingBox);
});

RTTI_DEFINE_CLASS(App::WorldCommunityEntryData, {
    RTTI_PROPERTY(sectorHash);
    RTTI_PROPERTY(registryIndex);
    RTTI_PROPERTY(communityIndex);
    RTTI_PROPERTY(communityCount);
    RTTI_PROPERTY(communityID);
    RTTI_PROPERTY(entryIndex);
    RTTI_PROPERTY(entryCount);
    RTTI_PROPERTY(entryName);
    RTTI_PROPERTY(entryPhase);
});

RTTI_DEFINE_CLASS(App::WorldInspector, {
    RTTI_METHOD(IsReady);
    RTTI_METHOD(GetFrustumDistance);
    RTTI_METHOD(SetFrustumDistance);
    RTTI_METHOD(GetTargetingDistance);
    RTTI_METHOD(SetTargetingDistance);
    RTTI_METHOD(IsDiscoverMode);
    RTTI_METHOD(SetDiscoverMode);

    RTTI_METHOD(ResolveSectorDataFromNodeID);
    RTTI_METHOD(ResolveSectorDataFromNodeInstance);
    RTTI_METHOD(ResolveNodeRefFromNodeHash);
    RTTI_METHOD(ResolveCommunityIDFromEntityID);
    RTTI_METHOD(ResolveCommunityEntryDataFromEntityID);
    RTTI_METHOD(FindStreamedNode);
    RTTI_METHOD(GetStreamedNodesInFrustum);
    RTTI_METHOD(GetStreamedNodesInCrosshair);
    RTTI_METHOD(GetStreamedNodeGeometry);

    RTTI_METHOD(ApplyHighlightEffect);
    RTTI_METHOD(SetNodeVisibility);
    RTTI_METHOD(ToggleNodeVisibility);
    RTTI_METHOD(GetNodeVisibility);

    RTTI_METHOD(ComputeNodeRefHash);
    RTTI_METHOD(GetPhysicsTraceObject);
    RTTI_METHOD(GetPhysicsProxyGeometry);
    RTTI_METHOD(GetPhysicsObjectGeometry);

    RTTI_METHOD(ProjectWorldPoint);
    RTTI_METHOD(GetFrustumNearPlane);
});
