#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"

namespace App
{
class ArchiveLoader;

class ArchiveWatcher : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    ArchiveWatcher(std::filesystem::path aHotDir);

private:
    using FileWatch = filewatch::FileWatch<std::filesystem::path>;
    using FileEvent = filewatch::Event;

    void OnFilesystemUpdate(const std::filesystem::path& aPath, FileEvent aEvent);
    void ScheduleReload();
    void CancelReload();

    std::filesystem::path m_archiveHotDir;
    std::unique_ptr<FileWatch> m_watch;
    std::chrono::time_point<std::chrono::steady_clock> m_reloadTime;
    std::chrono::milliseconds m_reloadDelay;
    std::mutex m_reloadLock;
    bool m_reloadQueued;
    bool m_threadStarted;
};
}
