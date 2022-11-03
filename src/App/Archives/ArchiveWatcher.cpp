#include "ArchiveWatcher.hpp"
#include "App/Archives/ArchiveLoader.hpp"
#include "Core/Facades/Container.hpp"

App::ArchiveWatcher::ArchiveWatcher(std::filesystem::path aHotDir)
    : AbstractWatcher(std::chrono::milliseconds(500))
    , m_archiveHotDir(std::move(aHotDir))
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
        Watch(m_archiveHotDir);
    }
}

bool App::ArchiveWatcher::Filter(const std::filesystem::path& aPath)
{
    return aPath.extension() == L".archive";
}

bool App::ArchiveWatcher::Process()
{
    return Core::Resolve<ArchiveLoader>()->SwapArchives(m_archiveHotDir);
}
