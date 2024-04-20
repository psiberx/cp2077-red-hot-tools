#include "ArchiveReporter.hpp"
#include "Core/Facades/Container.hpp"
#include "App/Runtime/ResourceRegistry.hpp"
#include "Red/ResourceDepot.hpp"

void App::ArchiveReporter::OnBootstrap()
{
    HookAfter<Raw::ResourceDepot::RequestResource>(&OnRequestResource);
}

void App::ArchiveReporter::OnRequestResource(Red::ResourceDepot* aDepot, const uintptr_t* aResourceHandle,
                                             Red::ResourcePath aResourcePath, const int32_t* aArchiveHandle)
{
    if (!*aResourceHandle)
    {
        auto archiveInfo = GetArchiveInfo(aDepot, aArchiveHandle);

        if (archiveInfo.scope == Red::ArchiveScope::Content || archiveInfo.scope == Red::ArchiveScope::DLC)
            return;

        auto resourcePathStr = Core::Resolve<ResourceRegistry>()->ResolveResorcePath(aResourcePath);

        LogWarning(R"(Resource not found: hash={} path="{}" archive="{}")",
                   aResourcePath.hash,
                   !resourcePathStr.empty() ? resourcePathStr.data() : "?",
                   !archiveInfo.path.empty() ? archiveInfo.path.data() : "?");
    }
}

App::ArchiveReporter::ArchiveInfo App::ArchiveReporter::GetArchiveInfo(Red::ResourceDepot* aDepot,
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
