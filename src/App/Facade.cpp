#include "Facade.hpp"
#include "App/Archives/ArchiveLoader.hpp"
#include "App/Environment.hpp"
#include "App/Scripts/ScriptLoader.hpp"
#include "App/Shared/ResourcePathRegistry.hpp"
#include "Core/Facades/Container.hpp"
#include "Red/Scripting.hpp"

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

Red::CName App::Facade::GetTypeName(const Red::WeakHandle<Red::ISerializable>& aInstace)
{
    if (!aInstace)
        return {};

    return aInstace.instance->GetType()->GetName();
}

bool App::Facade::IsInstanceOf(const Red::WeakHandle<Red::ISerializable>& aInstace, Red::CName aType)
{
    return aInstace && aInstace.instance->GetType()->IsA(Red::GetType(aType));
}

uint64_t App::Facade::GetObjectHash(const Red::WeakHandle<Red::ISerializable>& aInstace)
{
    return reinterpret_cast<uint64_t>(aInstace.instance);
}

Red::Handle<Red::ISerializable> App::Facade::CloneObject(const Red::Handle<Red::ISerializable>& aInstace)
{
    Red::Handle<Red::ISerializable> clone;
    Raw::ISerializable::Clone(clone, aInstace);
    return clone;
}

Red::DynArray<Red::Handle<Red::IComponent>> App::Facade::GetEntityComponents(const Red::WeakHandle<Red::Entity>& aEntity)
{
    if (aEntity.Expired())
        return {};

    return Raw::Entity::ComponentsStorage::Ptr(aEntity.instance)->components;
}

Red::ResourceAsyncReference<> App::Facade::GetEntityTemplatePath(const Red::WeakHandle<Red::Entity>& aEntity)
{
    if (aEntity.Expired())
        return {};

    return Raw::Entity::TemplatePath::Ref(aEntity.instance);
}

Red::DynArray<Red::CName> App::Facade::GetEntityVisualTags(const Red::WeakHandle<Red::Entity>& aEntity)
{
    if (aEntity.Expired())
        return {};

    return aEntity.instance->visualTags.tags;
}

Red::CString App::Facade::GetResourcePath(uint64_t aResourceHash)
{
    return ResourcePathRegistry::Get()->ResolvePath(aResourceHash);
}
