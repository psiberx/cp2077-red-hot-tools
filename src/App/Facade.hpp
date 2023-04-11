#pragma once

#include "App/Project.hpp"

namespace App
{
class Facade : public Red::IScriptable
{
public:
    static void ReloadArchives();
    static void ReloadScripts();
    static Red::CString GetVersion();

    static Red::DynArray<Red::Handle<Red::IComponent>> GetComponents(const Red::WeakHandle<Red::Entity>& aEntity);

    RTTI_IMPL_TYPEINFO(Facade);
};
}

RTTI_DEFINE_CLASS(App::Facade, App::Project::Name, {
    RTTI_ABSTRACT();
    RTTI_METHOD(ReloadArchives);
    RTTI_METHOD(ReloadScripts);
    RTTI_METHOD(GetVersion, "Version");
    RTTI_METHOD(GetComponents);
})
