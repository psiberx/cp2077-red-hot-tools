#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"
#include "Red/ResourcePath.hpp"

namespace App
{
class ResourceRegistry
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    ResourceRegistry(const std::filesystem::path& aMetadataDir);

    std::string_view ResolveResorcePath(Red::ResourcePath aPath);

protected:
    void OnBootstrap() override;

    static void OnCreateResourcePath(Red::ResourcePath* aPath, const Red::StringView* aPathStr);

    inline static std::shared_mutex s_resourcePathLock;
    inline static Core::Map<Red::ResourcePath, std::string> s_resourcePathMap;
};
}
