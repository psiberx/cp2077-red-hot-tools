#include "ArchiveLoader.hpp"
#include "Red/GameEngine.hpp"
#include "Red/ResourceBank.hpp"
#include "Red/ResourceDepot.hpp"

bool App::ArchiveLoader::SwapArchives(const std::filesystem::path& aArchiveHotDir)
{
    std::unique_lock updateLock(m_updateLock);
    DepotLock depotLock;

    Red::DynArray<Red::ArchiveGroup*> archiveGroups;
    Red::DynArray<Red::CString> archiveHotPaths;
    Red::DynArray<Red::CString> archiveModPaths;

    LogInfo("[ArchiveLoader] Archives reload requested.");

    if (!CollectArchiveGroups(archiveGroups))
    {
        LogError("[ArchiveLoader] The game resource depot is not initialized. Aborting.");
        return false;
    }

    if (!ResolveArchivePaths(archiveGroups, aArchiveHotDir, archiveHotPaths, archiveModPaths))
    {
        LogWarning("[ArchiveLoader] No archives found in [{}].", aArchiveHotDir.string());
        return false;
    }

    Red::DynArray<Red::ResourcePath> hotResources;

    LogInfo("[ArchiveLoader] Unloading game archives...");

    UnloadModArchives(archiveGroups, archiveModPaths);

    LogInfo("[ArchiveLoader] Moving updated archives...");

    MoveArchiveFiles(archiveHotPaths, archiveModPaths);

    LogInfo("[ArchiveLoader] Loading updated archives...");

    LoadModArchives(archiveGroups, archiveModPaths, hotResources);

    LogInfo("[ArchiveLoader] Resetting resource cache...");

    InvalidateResources(hotResources);

    LogInfo("[ArchiveLoader] Reloading archive extensions...");

    MoveExtensionFiles(archiveGroups, aArchiveHotDir);
    ReloadExtensions();

    LogInfo("[ArchiveLoader] Archives reload completed.");

    return true;
}

bool App::ArchiveLoader::CollectArchiveGroups(Red::DynArray<Red::ArchiveGroup*>& aGroups)
{
    auto depot = Red::ResourceDepot::Get();

    if (!depot)
        return false;

    for (auto& group : depot->groups)
    {
        if (group.scope == Red::ArchiveScope::Mod)
        {
            aGroups.PushBack(&group);
        }
    }

    return aGroups.size > 0;
}

bool App::ArchiveLoader::ResolveArchivePaths(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                             const std::filesystem::path& aArchiveHotDir,
                                             Red::DynArray<Red::CString>& aArchiveHotPaths,
                                             Red::DynArray<Red::CString>& aArchiveModPaths)
{
    std::error_code error;
    auto iterator = std::filesystem::recursive_directory_iterator(aArchiveHotDir, error);

    if (error)
        return false;

    const std::filesystem::path defaultModDir = aGroups[0]->basePath.c_str();

    for (const auto& entry : iterator)
    {
        if (entry.is_regular_file() && entry.path().extension() == L".archive")
        {
            const auto& archiveName = entry.path().filename();
            const auto& archiveHotPath = entry.path();

            if (!std::ifstream(archiveHotPath).good())
                return false;

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
                const auto& archiveModPath = defaultModDir / archiveName;

                aArchiveHotPaths.EmplaceBack(archiveHotPath.string().c_str());
                aArchiveModPaths.EmplaceBack(archiveModPath.string().c_str());
            }
        }
    }

    return true;
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
            Red::Handle<Red::CResource> resource;
            Raw::ResourceBank::ForgetResource(loader->unk48, resource, path);
        }
        {
            auto* tokenWeak = loader->tokens.Get(path);
            if (tokenWeak && tokenWeak->instance)
            {
                tokenWeak->refCount = nullptr;
                tokenWeak->instance = nullptr;

                loader->tokens.Remove(path);

                // auto token = tokenWeak->Lock();
                // if (token->IsFinished())
                // {
                //    loader->tokens.Remove(path);
                // }
            }
        }
    }
}

void App::ArchiveLoader::MoveExtensionFiles(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                            const std::filesystem::path& aHotDir)
{
    std::error_code error;
    auto iterator = std::filesystem::recursive_directory_iterator(aHotDir, error);

    if (error)
        return;

    const std::filesystem::path defaultModDir = aGroups[0]->basePath.c_str();

    for (const auto& entry : iterator)
    {
        if (entry.is_regular_file())
        {
            const auto& extension = entry.path().extension();

            if (extension == L".xl" || extension == L".yaml" || extension == L".yml")
            {
                std::filesystem::path configModPath;
                bool configFound = false;

                for (const auto& group : aGroups)
                {
                    configModPath = group->basePath.c_str();
                    configModPath /= entry.path().filename();

                    if (std::filesystem::exists(configModPath))
                    {
                        configFound = true;
                        break;
                    }
                }

                if (!configFound)
                {
                    configModPath = defaultModDir / entry.path().filename();
                }

                if (std::filesystem::exists(configModPath))
                {
                    if (!std::filesystem::remove(configModPath, error))
                        continue;
                }

                std::filesystem::rename(entry.path(), configModPath);
            }
        }
    }
}

void App::ArchiveLoader::ReloadExtensions()
{
    HookOnceAfter<Raw::CBaseEngine::MainLoopTick>(+[]() {
        Red::ExecuteFunction("ArchiveXL", "Reload", nullptr);
    });
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
