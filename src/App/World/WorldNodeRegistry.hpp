#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"
#include "Red/StreamingSector.hpp"
#include "Red/WorldNode.hpp"

namespace App
{
struct WorldNodeInstanceStaticData
{
    uint64_t sectorHash{0};
    int32_t instanceIndex{-1};
    uint32_t instanceCount{0};
    int32_t nodeIndex{-1};
    uint32_t nodeCount{0};
    uint64_t nodeID{0};
    uint64_t parentID{0};
    Red::CName nodeType;
};

struct WorldCommunityStaticData
{
    uint64_t sectorHash{0};
    int32_t communityIndex{-1};
    uint32_t communityCount{0};
    Red::EntityID communityID;
};

struct WorldNodeInstanceRuntimeData
{
    Red::CompiledNodeInstanceSetupInfo* setup{};
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
};

struct IWorldNodeInstanceWatcher
{
    virtual void OnNodeStreamedIn(uint64_t aNodeHash,
                                  Red::worldNode* aNodeDefinition,
                                  Red::worldINodeInstance* aNodeInstance,
                                  Red::CompiledNodeInstanceSetupInfo* aNodeSetup) = 0;
    virtual void OnNodeStreamedOut(uint64_t aNodeHash) = 0;
};

class WorldNodeRegistry
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    WorldNodeInstanceStaticData GetNodeStaticData(Red::NodeRef aNodeRef);
    WorldNodeInstanceStaticData GetNodeStaticData(const Red::WeakHandle<Red::worldINodeInstance>& aNode);
    WorldNodeInstanceRuntimeData GetNodeRuntimeData(const Red::WeakHandle<Red::worldINodeInstance>& aNode);
    Core::Vector<WorldNodeInstanceRuntimeData> GetAllStreamedNodes();
    WorldCommunityStaticData GetCommunityStaticData(uint64_t aCommunityID);
    void ClearRuntimeData();

    void RegisterWatcher(IWorldNodeInstanceWatcher* aWatcher);
    void UnregisterWatcher(IWorldNodeInstanceWatcher* aWatcher);

    Red::Handle<Red::worldINodeInstance> FindStreamedNodeInstance(uint64_t aNodeID);

protected:
    void OnBootstrap() override;

    static void OnStreamingSectorPrepare(Red::worldStreamingSector* aSector, uint64_t);
    static void OnStreamingSectorDestruct(Red::worldStreamingSector* aSector);
    static void OnNodeInstanceInitialize(Red::worldINodeInstance* aNodeInstance,
                                         Red::CompiledNodeInstanceSetupInfo* aNodeSetup, void*);
    static void OnNodeInstanceAttach(Red::worldINodeInstance* aNodeInstance, void*);
    static void OnNodeInstanceDetach(Red::worldINodeInstance* aNodeInstance, void*);

    static WorldNodeInstanceStaticData GetNodeStaticData(Red::CompiledNodeInstanceSetupInfo* aNodeSetup);
    static WorldNodeInstanceRuntimeData GetNodeRuntimeData(Red::CompiledNodeInstanceSetupInfo* aNodeSetup);
    static Red::CompiledNodeInstanceSetupInfo* GetNodeSetupInfo(Red::worldINodeInstance* aNodeInstance);

    inline static std::shared_mutex s_nodeStaticDataLock;
    inline static std::shared_mutex s_nodeInstanceDataLock;
    inline static Core::Map<Red::NodeRef, WorldNodeInstanceStaticData> s_nodeRefToStaticDataMap;
    inline static Core::Map<Red::CompiledNodeInstanceSetupInfo*, WorldNodeInstanceStaticData> s_nodeSetupToStaticDataMap;
    inline static Core::Map<Red::CompiledNodeInstanceSetupInfo*, WorldNodeInstanceRuntimeData> s_nodeSetupToRuntimeDataMap;
    inline static Core::Map<Red::worldINodeInstance*, Red::CompiledNodeInstanceSetupInfo*> s_nodeInstanceToNodeSetupMap;
    inline static Core::Map<uint64_t, WorldCommunityStaticData> s_communityStaticDataMap;

    inline static Core::Vector<IWorldNodeInstanceWatcher*> s_watchers;
};
}
