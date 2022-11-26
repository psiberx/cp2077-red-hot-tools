#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"

namespace App
{
class TweakLoader
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    TweakLoader(std::filesystem::path aTweaksDir);

    void ReloadTweaks();
    void ReloadTweaks(const Core::Vector<Red::CString>& aTargets);

private:

    std::filesystem::path m_tweaksDir;
    std::mutex m_updateLock;
};
}
