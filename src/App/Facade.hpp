#pragma once

#include "App/Project.hpp"

namespace App
{
class Facade : public Red::IScriptable
{
public:
    static Red::CString GetVersion();

    static void ReloadArchives();
    static void ReloadScripts();
    static void ReloadTweaks();

    RTTI_IMPL_TYPEINFO(Facade);
};
}

RTTI_DEFINE_CLASS(App::Facade, App::Project::Name, {
    RTTI_ABSTRACT();
    RTTI_METHOD(GetVersion, "Version");
    RTTI_METHOD(ReloadArchives);
    RTTI_METHOD(ReloadScripts);
    RTTI_METHOD(ReloadTweaks);
})
