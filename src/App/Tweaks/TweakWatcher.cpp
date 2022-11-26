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
    Core::Vector<Red::CString> targets;

    if (!Read(targets))
        return false;

    if (!CleanUp())
        return false;

    Core::Resolve<TweakLoader>()->ReloadTweaks(targets);
    return true;
}

bool App::TweakWatcher::Read(Core::Vector<Red::CString>& aTargets)
{
    try
    {
        std::ifstream in(m_requestPath);
        std::string line;
        while (std::getline(in, line))
        {
            if (!line.empty())
            {
                aTargets.emplace_back(line.c_str());
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
