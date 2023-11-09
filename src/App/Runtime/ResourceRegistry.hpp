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
    int32_t nodeIndex{-1};
    uint32_t nodeCount{0};
    uint64_t nodeID{0};
    Red::CName nodeType;
};

struct WorldNodeDynamicData
{
    Red::WeakHandle<Red::worldNode> node;
    Red::CompiledNodeInstanceSetupInfo* setup;
};

class ResourceRegistry
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    ResourceRegistry(const std::filesystem::path& aMetadataDir);

    std::string_view ResolveResorcePath(Red::ResourcePath aPath);
    WorldNodeStaticData GetWorldNodeStaticData(uint64_t aHash);
    WorldNodeStaticData GetWorldNodeStaticData(void* aPtr);
    Core::Vector<WorldNodeDynamicData> GetStreamedNodes();
    void ClearRuntimeData();

protected:
    void OnBootstrap() override;

    static void OnCreateResourcePath(Red::ResourcePath* aPath, const Red::StringView* aPathStr);
    static void OnStreamingSectorPrepare(Red::worldStreamingSector* aSector, uint64_t);
    static void OnStreamingSectorDestruct(Red::worldStreamingSector* aSector);

    inline static std::shared_mutex s_resourcePathLock;
    inline static Core::Map<Red::ResourcePath, std::string> s_resourcePathMap;

    inline static std::shared_mutex s_nodeSectorLock;
    inline static Core::Map<uint64_t, WorldNodeStaticData> s_nodeRefToSectorMap;
    inline static Core::Map<uintptr_t, WorldNodeStaticData> s_nodePtrToSectorMap;
    inline static Core::Map<uintptr_t, WorldNodeDynamicData> s_nodePtrToNodeMap;
};
}
