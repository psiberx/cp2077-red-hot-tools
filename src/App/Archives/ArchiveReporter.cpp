#include "ArchiveReporter.hpp"
#include "Core/Facades/Container.hpp"
#include "App/Runtime/ResourceRegistry.hpp"
#include "Red/ResourceDepot.hpp"

void App::ArchiveReporter::OnBootstrap()
{
    HookAfter<Raw::ResourceDepot::RequestResource>(&OnRequestResource);
}

void App::ArchiveReporter::OnRequestResource(Red::ResourceDepot* aDepot, uintptr_t* aHandle,
                                             Red::ResourcePath aPath, uintptr_t)
{
    if (!*aHandle)
    {
        auto pathStr = Core::Resolve<ResourceRegistry>()->ResolveResorcePath(aPath);
        if (pathStr.empty())
        {
            LogWarning("Resource not found: {}", aPath.hash);
        }
        else
        {
            LogWarning("Resource not found: {}", pathStr);
        }
    }
}
