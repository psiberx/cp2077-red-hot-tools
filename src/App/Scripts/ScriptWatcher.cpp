#include "ScriptWatcher.hpp"
#include "App/Scripts/ScriptLoader.hpp"
#include "Core/Facades/Container.hpp"

App::ScriptWatcher::ScriptWatcher(std::filesystem::path aRequestPath)
    : AbstractWatcher(aRequestPath, std::chrono::milliseconds(100))
    , m_requestPath(std::move(aRequestPath))
{
    CleanUp();
}

bool App::ScriptWatcher::Process()
{
    if (!CleanUp())
        return false;

    Core::Resolve<ScriptLoader>()->ReloadScripts();
    return true;
}

bool App::ScriptWatcher::CleanUp()
{
    std::error_code error;
    return std::filesystem::remove(m_requestPath, error);
}
