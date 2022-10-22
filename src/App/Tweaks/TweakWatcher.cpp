#include "TweakWatcher.hpp"
#include "App/Tweaks/TweakLoader.hpp"
#include "Core/Facades/Container.hpp"

App::TweakWatcher::TweakWatcher(std::filesystem::path aRequestPath)
    : AbstractWatcher(aRequestPath, std::chrono::milliseconds(100))
    , m_requestPath(std::move(aRequestPath))
{
    CleanUp();
}

bool App::TweakWatcher::Process()
{
    std::vector<std::filesystem::path> paths;

    if (!Read(paths))
        return false;

    if (!CleanUp())
        return false;

    Core::Resolve<TweakLoader>()->ReloadTweaks(paths);
    return true;
}

bool App::TweakWatcher::Read(std::vector<std::filesystem::path>& aPaths)
{
    try
    {
        std::ifstream in(m_requestPath);
        std::string line;
        while (std::getline(in, line))
        {
            if (!line.empty())
            {
                aPaths.emplace_back(line);
            }
        }
        return true;
    }
    catch (const std::exception& ex)
    {
        LogError(ex.what());
        return false;
    }
}

bool App::TweakWatcher::CleanUp()
{
    std::error_code error;
    return std::filesystem::remove(m_requestPath, error);
}
