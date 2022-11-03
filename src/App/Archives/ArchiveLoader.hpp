#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"
#include "Red/ResourceDepot.hpp"

namespace App
{
class ArchiveLoader
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    ArchiveLoader(std::filesystem::path aArchiveModDir);

    bool SwapArchives(const std::filesystem::path& aArchiveHotDir);

private:
    static bool CollectArchiveGroups(Red::DynArray<Red::ArchiveGroup*>& aGroups);
    static bool ResolveArchivePaths(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                    const std::filesystem::path& aArchiveHotDir,
                                    const std::filesystem::path& aArchiveModDir,
                                    Red::DynArray<Red::CString>& aArchiveHotPaths,
                                    Red::DynArray<Red::CString>& aArchiveModPaths);
    static void MoveArchiveFiles(Red::DynArray<Red::CString>& aHotPaths, Red::DynArray<Red::CString>& aModPaths);
    static void UnloadModArchives(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                  const Red::DynArray<Red::CString>& aArchivePaths);
    static void LoadModArchives(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                const Red::DynArray<Red::CString>& aArchivePaths,
                                Red::DynArray<Red::ResourcePath>& aLoadedResources);
    static Red::Archive* FindArchivePosition(Red::DynArray<Red::Archive>& aArchives, const Red::CString& aArchivePath);
    static void InvalidateResources(const Red::DynArray<Red::ResourcePath>& aPaths);
    static void MoveExtensionFiles(const std::filesystem::path& aHotDir, const std::filesystem::path& aModDir);
    static void ReloadExtensions();

    struct DepotLock
    {
        DepotLock();
        ~DepotLock();

        std::unique_lock<std::shared_mutex> m_guard;
        inline static std::shared_mutex s_depotLock;
    };

    std::filesystem::path m_archiveModDir;
    std::mutex m_updateLock;
};
}
