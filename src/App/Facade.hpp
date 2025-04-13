#pragma once

#include "App/Project.hpp"

namespace App
{
class Facade : public Red::IScriptable
{
public:
    static Red::CString GetVersion();

    static bool HotInstall(const Red::CString& aPath);
    static void ReloadArchives();
    static void ReloadScripts();
    static void ReloadTweaks();

    static Red::CName GetTypeName(const Red::WeakHandle<Red::ISerializable>& aInstace);
    static bool IsInstanceOf(const Red::WeakHandle<Red::ISerializable>& aInstace, Red::CName aType);
    static uint64_t GetObjectHash(const Red::WeakHandle<Red::ISerializable>& aInstace);
    static Red::Handle<Red::ISerializable> CloneObject(const Red::Handle<Red::ISerializable>& aInstace);

    static Red::DynArray<Red::Handle<Red::IComponent>> GetEntityComponents(const Red::WeakHandle<Red::Entity>& aEntity);
    static Red::ResourceAsyncReference<> GetEntityTemplatePath(const Red::WeakHandle<Red::Entity>& aEntity);
    static Red::DynArray<Red::CName> GetEntityVisualTags(const Red::WeakHandle<Red::Entity>& aEntity);

    static uint64_t GetComponentAppearanceResourceHash(const Red::Handle<Red::IComponent>& aComponent);
    static Red::CName GetComponentAppearanceDefinition(const Red::Handle<Red::IComponent>& aComponent);

    static Red::CString GetResourcePath(uint64_t aHash);
    static Red::CString GetReferencePath(const Red::Handle<Red::ISerializable>& aInstace, Red::CName aPropName);
    static uint64_t GetCRUIDHash(Red::CRUID aValue);

    static Red::DynArray<Red::WeakHandle<Red::ISerializable>> GetAllHandles();

    RTTI_IMPL_TYPEINFO(Facade);
};
}

RTTI_DEFINE_CLASS(App::Facade, App::Project::Name, {
    RTTI_ABSTRACT();
    RTTI_METHOD(GetVersion, "Version");

    RTTI_METHOD(HotInstall);
    RTTI_METHOD(ReloadArchives);
    RTTI_METHOD(ReloadScripts);
    RTTI_METHOD(ReloadTweaks);

    RTTI_METHOD(GetTypeName);
    RTTI_METHOD(IsInstanceOf);
    RTTI_METHOD(GetObjectHash);
    RTTI_METHOD(CloneObject);

    RTTI_METHOD(GetEntityComponents);
    RTTI_METHOD(GetEntityTemplatePath);
    RTTI_METHOD(GetEntityVisualTags);

    RTTI_METHOD(GetComponentAppearanceResourceHash);
    RTTI_METHOD(GetComponentAppearanceDefinition);

    RTTI_METHOD(GetResourcePath);
    RTTI_METHOD(GetReferencePath);
    RTTI_METHOD(GetCRUIDHash);

    RTTI_METHOD(GetAllHandles);
})
