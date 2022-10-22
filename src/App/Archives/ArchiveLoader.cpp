#include "ArchiveLoader.hpp"
#include "Red/ResourceBank.hpp"
#include "Red/ResourceDepot.hpp"

App::ArchiveLoader::ArchiveLoader(std::filesystem::path aArchiveModDir)
    : m_archiveModDir(std::move(aArchiveModDir))
{
}

void App::ArchiveLoader::SwapArchives(const std::filesystem::path& aArchiveHotDir)
{
    std::unique_lock updateLock(m_updateLock);
    DepotLock depotLock;

    Red::DynArray<Red::ArchiveGroup*> archiveGroups;
    Red::DynArray<Red::CString> archiveHotPaths;
    Red::DynArray<Red::CString> archiveModPaths;
    Red::DynArray<Red::ResourcePath> hotResources;

    CollectArchiveGroups(archiveGroups);
    ResolveArchivePaths(archiveGroups, aArchiveHotDir, m_archiveModDir, archiveHotPaths, archiveModPaths);
    UnloadModArchives(archiveGroups, archiveModPaths);
    MoveArchiveFiles(archiveHotPaths, archiveModPaths);
    LoadModArchives(archiveGroups, archiveModPaths, hotResources);
    InvalidateResources(hotResources);
    MoveExtensionFiles(aArchiveHotDir, m_archiveModDir);
    ReloadExtensions();
}

void App::ArchiveLoader::CollectArchiveGroups(Red::DynArray<Red::ArchiveGroup*>& aGroups)
{
    auto depot = Red::ResourceDepot::Get();

    if (!depot)
        return;

    for (auto& group : depot->groups)
    {
        if (group.scope == Red::ArchiveScope::Mod)
        {
            aGroups.PushBack(&group);
        }
    }
}

void App::ArchiveLoader::ResolveArchivePaths(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                             const std::filesystem::path& aArchiveHotDir,
                                             const std::filesystem::path& aArchiveModDir,
                                             Red::DynArray<Red::CString>& aArchiveHotPaths,
                                             Red::DynArray<Red::CString>& aArchiveModPaths)
{
    std::error_code error;
    auto iterator = std::filesystem::recursive_directory_iterator(aArchiveHotDir, error);

    if (error)
        return;

    for (const auto& entry : iterator)
    {
        if (entry.is_regular_file() && entry.path().extension() == L".archive")
        {
            const auto& archiveName = entry.path().filename();
            const auto& archiveHotPath = entry.path();

            bool archiveFound = false;

            for (const auto& group : aGroups)
            {
                for (const auto& archive : group->archives)
                {
                    if (std::string(archive.path.c_str()).ends_with(archiveName.string()))
                    {
                        const auto& archiveModPath = std::filesystem::path(group->basePath.c_str()) / archiveName;

                        aArchiveHotPaths.EmplaceBack(archiveHotPath.string().c_str());
                        aArchiveModPaths.EmplaceBack(archiveModPath.string().c_str());

                        archiveFound = true;
                        break;
                    }
                }

                if (archiveFound)
                    break;
            }

            if (!archiveFound)
            {
                const auto& archiveModPath = aArchiveModDir / archiveName;

                aArchiveHotPaths.EmplaceBack(archiveHotPath.string().c_str());
                aArchiveModPaths.EmplaceBack(archiveModPath.string().c_str());
            }
        }
    }
}

void App::ArchiveLoader::MoveArchiveFiles(Red::DynArray<Red::CString>& aHotPaths,
                                          Red::DynArray<Red::CString>& aModPaths)
{
    std::error_code error;

    for (uint32_t i = 0; i < aHotPaths.size; ++i)
    {
        const std::filesystem::path hotPath = aHotPaths[i].c_str();
        const std::filesystem::path modPath = aModPaths[i].c_str();

        if (std::filesystem::exists(modPath))
        {
            if (!std::filesystem::remove(modPath, error))
                continue;
        }

        std::filesystem::rename(hotPath, modPath);
    }
}

void App::ArchiveLoader::UnloadModArchives(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                           const Red::DynArray<Red::CString>& aArchivePaths)
{
    Red::DynArray<Red::Archive> archivesToUnload;
    archivesToUnload.Reserve(aArchivePaths.size);

    for (const auto& group : aGroups)
    {
        for (const auto& archive : group->archives)
        {
            for (const auto& path : aArchivePaths)
            {
                if (archive.path == path)
                {
                    archivesToUnload.EmplaceBack(archive);
                    break;
                }
            }
        }
    }

    if (archivesToUnload.size > 0)
    {
        Raw::ResourceDepot::DestructArchives(archivesToUnload.entries, archivesToUnload.size);
    }
}

void App::ArchiveLoader::LoadModArchives(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                         const Red::DynArray<Red::CString>& aArchivePaths,
                                         Red::DynArray<Red::ResourcePath>& aLoadedResources)
{
    Red::ArchiveGroup hotGroup;
    Raw::ResourceDepot::LoadArchives(nullptr, hotGroup, aArchivePaths, aLoadedResources, false);

    for (const auto& archive : hotGroup.archives)
    {
        for (const auto& group : aGroups)
        {
            if (std::string(archive.path.c_str()).starts_with(group->basePath.c_str()))
            {
                auto* position = FindArchivePosition(group->archives, archive.path);

                if (position == group->archives.End())
                {
                    group->archives.EmplaceBack(archive);
                }
                else if (position->path == archive.path)
                {
                    *position = archive;
                }
                else
                {
                    group->archives.Emplace(position, archive);
                }

                break;
            }
        }
    }
}

Red::Archive* App::ArchiveLoader::FindArchivePosition(Red::DynArray<Red::Archive>& aArchives,
                                                      const Red::CString& aArchivePath)
{
    return std::lower_bound(aArchives.Begin(), aArchives.End(), aArchivePath,
                            [](const Red::Archive& aArchive, const Red::CString& aPath) {
                                return strcmp(aArchive.path.c_str(), aPath.c_str()) < 0;
                            });
}

void App::ArchiveLoader::InvalidateResources(const Red::DynArray<Red::ResourcePath>& aPaths)
{
    if (aPaths.size == 0)
        return;

    auto loader = Red::ResourceLoader::Get();

    std::unique_lock lock(loader->tokenLock);

    for (const auto& path : aPaths)
    {
        {
            auto tokenWeak = loader->tokens.Get(path);
            if (tokenWeak && !tokenWeak->Expired())
            {
                auto token = tokenWeak->Lock();
                if (token->IsFinished())
                {
                    loader->tokens.Remove(path);
                }
            }
        }
        {
            Red::Handle<Red::CResource> resource;
            Raw::ResourceBank::ForgetResource(loader->unk48, resource, path);
        }
    }
}

void App::ArchiveLoader::ReloadExtensions()
{
    Red::ExecuteFunction("ArchiveXL", "Reload", nullptr);
}

void App::ArchiveLoader::MoveExtensionFiles(const std::filesystem::path& aHotDir, const std::filesystem::path& aModDir)
{
    std::error_code error;
    auto iterator = std::filesystem::recursive_directory_iterator(aHotDir, error);

    if (error)
        return;

    // TODO: Search in groups, or use first group

    for (const auto& entry : iterator)
    {
        if (entry.is_regular_file())
        {
            const auto& extension = entry.path().extension();

            if (extension == L".xl" || extension == L".yaml")
            {
                const auto& hotPath = entry.path();
                const auto& modPath = aModDir / std::filesystem::relative(entry.path(), aHotDir);

                if (std::filesystem::exists(modPath))
                {
                    if (!std::filesystem::remove(modPath, error))
                        continue;
                }

                std::filesystem::rename(hotPath, modPath);
            }
        }
    }
}

App::ArchiveLoader::DepotLock::DepotLock()
    : m_guard(s_depotLock)
{
    HookBefore<Raw::ResourceDepot::RequestResource>(+[]() {
        std::shared_lock lock(s_depotLock);
    });
}

App::ArchiveLoader::DepotLock::~DepotLock()
{
    Unhook<Raw::ResourceDepot::RequestResource>();
}
