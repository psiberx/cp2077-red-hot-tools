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
    if (!aEntity)
        return {};

    return aEntity.instance->components;
}

Red::ResourceAsyncReference<> App::Facade::GetEntityTemplatePath(const Red::WeakHandle<Red::Entity>& aEntity)
{
    if (!aEntity)
        return {};

    return aEntity.instance->templatePath;
}

Red::DynArray<Red::CName> App::Facade::GetEntityVisualTags(const Red::WeakHandle<Red::Entity>& aEntity)
{
    if (!aEntity)
        return {};

    return aEntity.instance->visualTags.tags;
}

Red::CString App::Facade::GetResourcePath(uint64_t aResourceHash)
{
    auto path = ResourcePathRegistry::Get()->ResolvePath(aResourceHash);

    if (path.empty())
    {
        path = std::to_string(aResourceHash);
    }

    return path;
}

Red::CString App::Facade::GetReferencePath(const Red::Handle<Red::ISerializable>& aInstace, Red::CName aPropName)
{
    if (!aInstace || !aPropName)
        return {};

    auto prop = aInstace->GetType()->GetProperty(aPropName);

    if (!prop || prop->type->GetType() != Red::ERTTIType::ResourceReference)
        return {};

    auto hash = prop->GetValuePtr<Red::ResourceReference<>>(aInstace)->path;

    if (!hash)
        return {};

    auto path = ResourcePathRegistry::Get()->ResolvePath(hash);

    if (path.empty())
    {
        path = std::to_string(hash);
    }

    return path;
}

uint64_t App::Facade::GetCRUIDHash(Red::CRUID aValue)
{
    return aValue.unk00;
}

uint64_t App::Facade::GetComponentAppearanceResourceHash(const Red::Handle<Red::IComponent>& aComponent)
{
    return aComponent->appearancePath.hash;
}

Red::CName App::Facade::GetComponentAppearanceDefinition(const Red::Handle<Red::IComponent>& aComponent)
{
    return aComponent->appearanceName;
}
