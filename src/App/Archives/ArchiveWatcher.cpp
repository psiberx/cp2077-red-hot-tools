#include "ArchiveWatcher.hpp"
#include "App/Archives/ArchiveLoader.hpp"
#include "Core/Facades/Container.hpp"

App::ArchiveWatcher::ArchiveWatcher(std::filesystem::path aHotDir)
    : m_archiveHotDir(std::move(aHotDir))
    , m_reloadDelay(250)
    , m_reloadQueued(false)
    , m_threadStarted(false)
{
    bool canWatch = false;

    if (std::filesystem::exists(m_archiveHotDir))
    {
        canWatch = true;
    }
    else
    {
        std::error_code error;
        canWatch = std::filesystem::create_directory(m_archiveHotDir, error);
    }

    if (canWatch)
    {
        auto callback = [this](const std::filesystem::path& aPath, const FileEvent aEvent) {
            OnFilesystemUpdate(aPath, aEvent);
        };

        m_watch = std::make_unique<FileWatch>(m_archiveHotDir, callback);
    }
}

void App::ArchiveWatcher::OnFilesystemUpdate(const std::filesystem::path& aPath, const FileEvent aEvent)
{
    switch (aEvent)
    {
    case FileEvent::added:
    case FileEvent::modified:
    case FileEvent::renamed_new:
    {
        if (std::filesystem::exists(m_archiveHotDir / aPath))
        {
            ScheduleReload();
        }
        break;
    }
    default:
        return;
    };
}

void App::ArchiveWatcher::ScheduleReload()
{
    {
        std::unique_lock lock(m_reloadLock);
        m_reloadTime = std::chrono::steady_clock::now() + m_reloadDelay;

        if (m_reloadQueued)
            return;

        m_reloadQueued = true;

        if (m_threadStarted)
            return;

        m_threadStarted = true;
    }

    std::ignore = std::async(std::launch::async, [this] {
        while (true)
        {
            const auto now = std::chrono::steady_clock::now();
            const auto diff = std::chrono::duration_cast<std::chrono::milliseconds>(m_reloadTime - now);

            if (diff <= std::chrono::steady_clock::duration::zero())
                break;

            std::this_thread::sleep_for(diff);
        }

        std::unique_lock lock(m_reloadLock);

        if (m_reloadQueued)
        {
            Core::Resolve<ArchiveLoader>()->SwapArchives(m_archiveHotDir);
            m_reloadQueued = false;
        }

        m_threadStarted = false;
    });
}

void App::ArchiveWatcher::CancelReload()
{
    m_reloadQueued = false;
}
