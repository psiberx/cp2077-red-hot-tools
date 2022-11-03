#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Logging/LoggingAgent.hpp"

namespace App
{
class AbstractWatcher
    : public Core::Feature
    , public Core::LoggingAgent
{
public:
    static constexpr auto DefaulProcessingDelay = std::chrono::milliseconds(250);
    static constexpr auto DefaulRetryDelay = std::chrono::milliseconds(100);
    static constexpr auto DefaulRetryCount = 50;

    AbstractWatcher(std::chrono::milliseconds aProcessingDelay = DefaulProcessingDelay,
                    std::chrono::milliseconds aRetryDelay = DefaulRetryDelay,
                    int32_t aRetryCount = DefaulRetryCount);
    AbstractWatcher(const std::filesystem::path& aTarget,
                    std::chrono::milliseconds aProcessingDelay = DefaulProcessingDelay,
                    std::chrono::milliseconds aRetryDelay = DefaulRetryDelay,
                    int32_t aRetryCount = DefaulRetryCount);

protected:
    using FileWatch = filewatch::FileWatch<std::filesystem::path>;
    using FileEvent = filewatch::Event;

    void Watch(const std::filesystem::path& aTarget);
    void Track(const std::filesystem::path& aTarget, const std::filesystem::path& aPath, FileEvent aEvent);
    void Schedule();
    void Cancel();

    virtual bool Filter(const std::filesystem::path& aPath);
    virtual bool Process() = 0;

    std::chrono::milliseconds m_processingDelay;
    std::chrono::milliseconds m_retryDelay;
    int32_t m_retryCount;
    std::vector<std::unique_ptr<FileWatch>> m_watches;
    std::chrono::time_point<std::chrono::steady_clock> m_processingTime;
    std::mutex m_processingLock;
    bool m_processingScheduled;
    std::future<void> m_future;
    bool m_threadStarted;
};
}
