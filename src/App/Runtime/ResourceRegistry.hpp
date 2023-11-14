#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"
#include "Red/ResourcePath.hpp"
#include "Red/StreamingSector.hpp"
#include "Red/WorldNode.hpp"

namespace App
{
struct WorldNodeStaticData
{
    uint64_t sectorHash{0};
    int32_t instanceIndex{-1};
    uint32_t instanceCount{0};
    int32_t nodeIndex{-1};
    uint32_t nodeCount{0};
    uint64_t nodeID{0};
    Red::CName nodeType;
};

struct WorldNodeRuntimeData
{
    Red::CompiledNodeInstanceSetupInfo* setup{};
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
};

class ResourceRegistry
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    ResourceRegistry(const std::filesystem::path& aMetadataDir);

    std::string_view ResolveResorcePath(Red::ResourcePath aPath);
    WorldNodeStaticData GetNodeStaticData(Red::NodeRef aNodeRef);
    WorldNodeStaticData GetNodeStaticData(const Red::WeakHandle<Red::worldINodeInstance>& aNode);
    WorldNodeRuntimeData GetNodeRuntimeData(const Red::WeakHandle<Red::worldINodeInstance>& aNode);
    Core::Vector<WorldNodeRuntimeData> GetAllStreamedNodes();
    void ClearRuntimeData();

protected:
    void OnBootstrap() override;

    static void OnCreateResourcePath(Red::ResourcePath* aPath, const Red::StringView* aPathStr);
    static void OnStreamingSectorPrepare(Red::worldStreamingSector* aSector, uint64_t);
    static void OnStreamingSectorDestruct(Red::worldStreamingSector* aSector);
    static void OnNodeInstanceInitialize(Red::worldINodeInstance* aNodeInstance,
                                         Red::CompiledNodeInstanceSetupInfo* aNodeSetup, void*);

    WorldNodeStaticData GetNodeStaticData(Red::CompiledNodeInstanceSetupInfo* aNodeSetup);
    WorldNodeRuntimeData GetNodeRuntimeData(Red::CompiledNodeInstanceSetupInfo* aNodeSetup);

    inline static std::shared_mutex s_resourcePathLock;
    inline static Core::Map<Red::ResourcePath, std::string> s_resourcePathMap;

    inline static std::shared_mutex s_nodeStaticDataLock;
    inline static std::shared_mutex s_nodeRuntimeDataLock;
    inline static Core::Map<Red::NodeRef, WorldNodeStaticData> s_nodeRefToStaticDataMap;
    inline static Core::Map<Red::CompiledNodeInstanceSetupInfo*, WorldNodeStaticData> s_nodeSetupToStaticDataMap;
    inline static Core::Map<Red::CompiledNodeInstanceSetupInfo*, WorldNodeRuntimeData> s_nodeSetupToRuntimeDataMap;
    inline static Core::Map<Red::worldINodeInstance*, Red::CompiledNodeInstanceSetupInfo*> s_nodeInstanceToNodeSetupMap;
};
}
