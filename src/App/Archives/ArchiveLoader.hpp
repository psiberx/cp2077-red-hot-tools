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
    bool SwapArchives(const std::filesystem::path& aArchiveHotDir);

private:
    struct DepotLocker
    {
        DepotLocker();
        DepotLocker(DepotLocker&&) = default;
        ~DepotLocker();

        void Bypass(Red::ResourcePath aPath);

        std::unique_lock<std::shared_mutex> m_guard;
        inline static std::shared_mutex s_mutex;
        inline static Core::Map<Red::ResourcePath, bool> s_bypass;
    };

    static bool CollectArchiveGroups(Red::DynArray<Red::ArchiveGroup*>& aGroups);
    static bool ResolveArchivePaths(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                    const std::filesystem::path& aArchiveHotDir,
                                    Red::DynArray<Red::CString>& aArchiveHotPaths,
                                    Red::DynArray<Red::CString>& aArchiveModPaths);
    static void MoveArchiveFiles(Red::DynArray<Red::CString>& aHotPaths, Red::DynArray<Red::CString>& aModPaths);
    static void UnloadModArchives(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                  const Red::DynArray<Red::CString>& aArchivePaths);
    static void LoadModArchives(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                const Red::DynArray<Red::CString>& aArchivePaths,
                                Red::DynArray<Red::ResourcePath>& aLoadedResources);
    static Red::Archive* FindArchivePosition(Red::DynArray<Red::Archive>& aArchives, const Red::CString& aArchivePath);
    static bool InvalidateResources(const Red::DynArray<Red::ResourcePath>& aPaths,
                                    Core::UniquePtr<DepotLocker>& aDepotLocker);
    static void MoveExtensionFiles(const Red::DynArray<Red::ArchiveGroup*>& aGroups,
                                   const std::filesystem::path& aHotDir);
    static void ReloadExtensions();

    std::mutex m_updateLock;
};
}
