#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"
#include "Red/ResourcePath.hpp"
#include "Red/StreamingSector.hpp"

namespace App
{
class ResourceRegistry
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    std::string_view ResolveResorcePath(Red::ResourcePath aPath);
    std::string_view ResolveSectorPath(uint64_t aHash);
    std::string_view ResolveSectorPath(void* aPtr);
    void ClearRuntimeData();

protected:
    void OnBootstrap() override;

    static void OnCreateResourcePath(Red::ResourcePath* aPath, const Red::StringView* aPathStr);
    static void OnStreamingSectorReady(Red::worldStreamingSector* aSector, uint64_t);

    inline static std::shared_mutex s_resourcePathLock;
    inline static Core::Map<Red::ResourcePath, std::string> s_resourcePathMap;

    inline static std::shared_mutex s_nodeSectorLock;
    inline static Core::Map<uint64_t, Red::ResourcePath> s_nodeRefToSectorMap;
    inline static Core::Map<uintptr_t, Red::ResourcePath> s_nodePtrToSectorMap;
};
}
