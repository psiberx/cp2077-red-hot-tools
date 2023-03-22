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

    RTTI_IMPL_TYPEINFO(Facade);
};
}

RTTI_DEFINE_CLASS(App::Facade, App::Project::Name, {
    RTTI_ABSTRACT();
    RTTI_METHOD(ReloadArchives);
    RTTI_METHOD(ReloadScripts);
    RTTI_METHOD(GetVersion, "Version");
})
