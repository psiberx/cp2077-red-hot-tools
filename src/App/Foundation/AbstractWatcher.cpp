#include "AbstractWatcher.hpp"

App::AbstractWatcher::AbstractWatcher(std::chrono::milliseconds aProcessingDelay,
                                      std::chrono::milliseconds aRetryDelay,
                                      int32_t aRetryCount)
    : m_processingDelay(aProcessingDelay)
    , m_retryDelay(aRetryDelay)
    , m_retryCount(aRetryCount)
    , m_processingScheduled(false)
    , m_threadStarted(false)
{
}

App::AbstractWatcher::AbstractWatcher(const std::filesystem::path& aTarget,
                                      std::chrono::milliseconds aProcessingDelay,
                                      std::chrono::milliseconds aRetryDelay,
                                      int32_t aRetryCount)
    : AbstractWatcher(aProcessingDelay, aRetryDelay, aRetryCount)
{
    Watch(aTarget);
}

void App::AbstractWatcher::Watch(const std::filesystem::path& aTarget)
{
    std::error_code error;
    auto targetDir = std::filesystem::is_directory(aTarget) ? aTarget : aTarget.parent_path();
    auto callback = [this, targetDir](const std::filesystem::path& aPath, const FileEvent aEvent) {
        Track(targetDir, aPath, aEvent);
    };

    m_watches.emplace_back(std::make_unique<FileWatch>(aTarget, callback));
}

void App::AbstractWatcher::Track(const std::filesystem::path& aTarget, const std::filesystem::path& aPath,
                                 const FileEvent aEvent)
{
    switch (aEvent)
    {
    case FileEvent::added:
    case FileEvent::modified:
    case FileEvent::renamed_new:
    {
        if (std::filesystem::exists(aTarget / aPath) && Filter(aPath))
        {
            Schedule();
        }
        break;
    }
    default:
        return;
    };
}

void App::AbstractWatcher::Schedule()
{
    {
        std::unique_lock lock(m_processingLock);
        m_processingTime = std::chrono::steady_clock::now() + m_processingDelay;

        if (m_processingScheduled)
            return;

        m_processingScheduled = true;

        if (m_threadStarted)
            return;

        m_threadStarted = true;
    }

    m_future = std::async(std::launch::async, [this] {
        try
        {
            while (true)
            {
                const auto now = std::chrono::steady_clock::now();
                const auto diff = std::chrono::duration_cast<std::chrono::milliseconds>(m_processingTime - now);

                if (diff <= std::chrono::steady_clock::duration::zero())
                    break;

                std::this_thread::sleep_for(diff);
            }

            std::unique_lock lock(m_processingLock);

            if (m_processingScheduled)
            {
                if (m_retryCount == 0)
                {
                    Process();
                }
                else
                {
                    auto tryCounter = m_retryCount;
                    while (true)
                    {
                        if (Process())
                            break;

                        if (--tryCounter <= 0)
                            break;

                        std::this_thread::sleep_for(m_retryDelay);
                    }
                }
                m_processingScheduled = false;
            }

            m_threadStarted = false;
        }
        catch (const std::exception& ex)
        {
            std::unique_lock lock(m_processingLock);
            m_processingScheduled = false;
            m_threadStarted = false;
        }
    });
}

void App::AbstractWatcher::Cancel()
{
    m_processingScheduled = false;
}

bool App::AbstractWatcher::Filter(const std::filesystem::path& aPath)
{
    return true;
}
