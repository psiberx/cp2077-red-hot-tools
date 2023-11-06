#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"
#include "Red/ResourcePath.hpp"
#include "Red/StreamingSector.hpp"
#include "Red/WorldNode.hpp"

namespace App
{
struct StreamingSectorLocation
{
    uint64_t sectorHash{0};
    int32_t nodeIndex{-1};
};

class ResourceRegistry
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    ResourceRegistry(const std::filesystem::path& aMetadataDir);

    std::string_view ResolveResorcePath(Red::ResourcePath aPath);
    StreamingSectorLocation ResolveSectorLocation(uint64_t aHash);
    StreamingSectorLocation ResolveSectorLocation(void* aPtr);
    void ClearRuntimeData();

protected:
    void OnBootstrap() override;

    static void OnCreateResourcePath(Red::ResourcePath* aPath, const Red::StringView* aPathStr);
    static void OnStreamingSectorPrepare(Red::worldStreamingSector* aSector, uint64_t);
    static void OnStreamingSectorDestruct(Red::worldStreamingSector* aSector);

    inline static std::shared_mutex s_resourcePathLock;
    inline static Core::Map<Red::ResourcePath, std::string> s_resourcePathMap;

    inline static std::shared_mutex s_nodeSectorLock;
    inline static Core::Map<uint64_t, StreamingSectorLocation> s_nodeRefToSectorMap;
    inline static Core::Map<uintptr_t, StreamingSectorLocation> s_nodePtrToSectorMap;
};
}
