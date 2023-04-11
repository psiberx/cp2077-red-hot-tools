#include "Facade.hpp"
#include "App/Environment.hpp"
#include "App/Archives/ArchiveLoader.hpp"
#include "App/Scripts/ScriptLoader.hpp"
#include "Core/Facades/Container.hpp"
#include "Red/Entity.hpp"

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

Red::DynArray<Red::Handle<Red::IComponent>> App::Facade::GetComponents(const Red::WeakHandle<Red::Entity>& aEntity)
{
    if (aEntity.Expired())
        return {};

    return Raw::Entity::ComponentsStorage(aEntity.instance)->components;
}
