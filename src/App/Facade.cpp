#include "Facade.hpp"
#include "App/Environment.hpp"
#include "App/Project.hpp"
#include "App/Archives/ArchiveLoader.hpp"
#include "App/Scripts/ScriptLoader.hpp"
#include "Core/Facades/Container.hpp"

void App::Facade::ReloadArchives()
{
    Core::Resolve<ArchiveLoader>()->SwapArchives(Env::ArchiveHotDir());
}

void App::Facade::ReloadScripts()
{
    Core::Resolve<ScriptLoader>()->ReloadScripts();
}

Red::CString App::Facade::GetVersion()
{
    return Project::Version.to_string().c_str();
}

void App::Facade::OnRegister(Descriptor* aType)
{
    aType->SetName(Project::Name);
    aType->SetFlags({ .isAbstract = true });
}

void App::Facade::OnDescribe(Descriptor* aType)
{
    aType->AddFunction<&ReloadArchives>("ReloadArchives");
    aType->AddFunction<&ReloadScripts>("ReloadScripts");
    aType->AddFunction<&GetVersion>("Version");
}
