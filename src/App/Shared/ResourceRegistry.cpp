#include "ResourceRegistry.hpp"

App::ResourceRegistry::ResourceRegistry(const std::filesystem::path& aMetadataDir)
{
    auto resourceList = aMetadataDir / L"Resources.txt";
    if (std::filesystem::exists(resourceList))
    {
        std::thread([resourceList]() {
            LogInfo("[ResourceRegistry] Loading metadata...");

            std::ifstream f(resourceList);
            {
                std::unique_lock _(s_resourcePathLock);
                std::string resourcePath;
                while (std::getline(f, resourcePath))
                {
                    s_resourcePathMap[Red::ResourcePath::HashSanitized(resourcePath.data())] = std::move(resourcePath);
                }
            }

            LogInfo("[ResourceRegistry] Loaded {} predefined hashes.", s_resourcePathMap.size());
        }).detach();
    }
}

void App::ResourceRegistry::OnBootstrap()
{
    HookAfter<Raw::ResourcePath::Create>(&OnCreateResourcePath);
}

void App::ResourceRegistry::OnCreateResourcePath(Red::ResourcePath* aPath, const Red::StringView* aPathStr)
{
    if (aPathStr)
    {
        std::unique_lock _(s_resourcePathLock);
        s_resourcePathMap[*aPath] = {aPathStr->data, aPathStr->size};
    }
}

std::string_view App::ResourceRegistry::ResolveResorcePath(Red::ResourcePath aPath)
{
    if (!aPath)
        return {};

    std::shared_lock _(s_resourcePathLock);
    const auto& it = s_resourcePathMap.find(aPath);

    if (it == s_resourcePathMap.end())
        return {};

    return it.value();
}
