#include "TweakLoader.hpp"
#include "Red/GameEngine.hpp"

App::TweakLoader::TweakLoader(std::filesystem::path aTweaksDir)
    : m_tweaksDir(std::move(aTweaksDir))
{
}

void App::TweakLoader::ReloadTweaks()
{
    HookOnceAfter<Raw::CBaseEngine::MainLoopTick>(+[]() {
        Red::ExecuteFunction("TweakXL", "Reload", nullptr);
    });
}

void App::TweakLoader::ReloadTweaks(const Core::Vector<Red::CString>& aTargets)
{
    ReloadTweaks();

    // if (aTargets.empty())
    // {
    //     ReloadTweaks();
    //     return;
    // }
    //
    // Core::Vector<Red::CString> importables;
    // Core::Vector<Red::CString> scriptables;
    //
    // std::error_code error;
    //
    // for (const auto& target : aTargets)
    // {
    //     if (std::filesystem::exists(m_tweaksDir / target.c_str(), error))
    //     {
    //         importables.emplace_back(target);
    //     }
    //     else
    //     {
    //         scriptables.emplace_back(target);
    //     }
    // }
}
