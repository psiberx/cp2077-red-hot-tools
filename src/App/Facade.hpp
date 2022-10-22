#pragma once

#include "Red/Rtti/Class.hpp"

namespace App
{
class Facade : public Red::Rtti::Class<Facade>
{
public:
    static void ReloadArchives();
    static void ReloadScripts();
    static Red::CString GetVersion();

private:
    friend Descriptor;
    static void OnRegister(Descriptor* aType);
    static void OnDescribe(Descriptor* aType);
};
}
