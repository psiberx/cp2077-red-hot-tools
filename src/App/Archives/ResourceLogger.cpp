#include "ResourceLogger.hpp"
#include "App/Shared/ResourcePathRegistry.hpp"
#include "Core/Facades/Container.hpp"
#include "Red/ResourceDepot.hpp"

void App::ResourceLogger::OnBootstrap()
{
    HookAfter<Raw::ResourceDepot::RequestResource>(&OnRequestResource);
    HookBefore<Raw::ResourceReference::EnsureLoaded>(&OnReferenceEnsureLoaded);
}

void App::ResourceLogger::OnRequestResource(Red::ResourceDepot* aDepot, const uintptr_t* aResourceHandle,
                                             Red::ResourcePath aResourcePath, const int32_t* aArchiveHandle)
{
    if (!*aResourceHandle)
    {
        if (s_knownBrokenPaths.contains(aResourcePath))
            return;

        auto archiveInfo = GetArchiveInfo(aDepot, aArchiveHandle);

        if (archiveInfo.scope == Red::ArchiveScope::Content || archiveInfo.scope == Red::ArchiveScope::DLC)
            return;

        auto resourcePathStr = Core::Resolve<ResourcePathRegistry>()->ResolvePath(aResourcePath);

        LogWarning(R"(Resource not found: hash={} path="{}" archive="{}")",
                   aResourcePath.hash,
                   !resourcePathStr.empty() ? resourcePathStr.data() : "?",
                   !archiveInfo.path.empty() ? archiveInfo.path.data() : "?");
    }
}

void App::ResourceLogger::OnReferenceEnsureLoaded(Red::ResourceReference<>* aReference)
{
    if (aReference->path && (!aReference->token || !aReference->token->IsFinished()))
    {
        if (s_knownBrokenPaths.contains(aReference->path))
            return;

        auto resourcePathStr = Core::Resolve<ResourcePathRegistry>()->ResolvePath(aReference->path);

        LogWarning(R"(Accessing unloaded rRef: hash={} path="{}")", aReference->path.hash,
                   !resourcePathStr.empty() ? resourcePathStr.data() : "?");
    }
}

App::ResourceLogger::ArchiveInfo App::ResourceLogger::GetArchiveInfo(Red::ResourceDepot* aDepot,
                                                                       const int32_t* aArchiveHandle)
{
    if (!aArchiveHandle || !*aArchiveHandle)
        return {};

    for (const auto& group : aDepot->groups)
    {
        for (const auto& archive : group.archives)
        {
            if (archive.asyncHandle == *aArchiveHandle)
            {
                return {group.scope, {archive.path.c_str() + group.basePath.Length()}};
            }
        }
    }

    return {};
}
