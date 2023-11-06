#include "Facade.hpp"
#include "App/Archives/ArchiveLoader.hpp"
#include "App/Environment.hpp"
#include "App/Scripts/ScriptLoader.hpp"
#include "Core/Facades/Container.hpp"

Red::CString App::Facade::GetVersion()
{
    return Project::Version.to_string().c_str();
}

void App::Facade::ReloadArchives()
{
    Core::Resolve<ArchiveLoader>()->SwapArchives(Env::ArchiveHotDir());
}

void App::Facade::ReloadScripts()
{
    Core::Resolve<ScriptLoader>()->ReloadScripts();
}

void App::Facade::ReloadTweaks()
{
    Red::CallStatic("TweakXL", "Reload");
}
