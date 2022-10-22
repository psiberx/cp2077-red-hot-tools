#include "Application.hpp"
#include "App/Environment.hpp"
#include "App/Archives/ArchiveLoader.hpp"
#include "App/Archives/ArchiveWatcher.hpp"
#include "App/Scripts/ScriptLoader.hpp"
#include "App/Scripts/ScriptReporter.hpp"
#include "App/Scripts/ScriptWatcher.hpp"
#include "App/Scripts/ObjectRegistry.hpp"
#include "App/Tweaks/TweakLoader.hpp"
#include "App/Tweaks/TweakWatcher.hpp"
#include "Core/Foundation/RuntimeProvider.hpp"
#include "Red/Foundation/RttiProvider.hpp"
#include "Vendor/MinHook/MinHookProvider.hpp"
#include "Vendor/RED4ext/RED4extProvider.hpp"
#include "Vendor/Spdlog/SpdlogProvider.hpp"

App::Application::Application(HMODULE aHandle, const RED4ext::Sdk* aSdk)
{
    Register<Core::RuntimeProvider>(aHandle)->SetBaseImagePathDepth(2);
    Register<Vendor::MinHookProvider>();
    Register<Vendor::SpdlogProvider>();
    Register<Red::RttiProvider>();

    Register<App::ArchiveLoader>(Env::ArchiveModDir());
    Register<App::ScriptLoader>(Env::ScriptSourceDir(), Env::ScriptBlobPath());
    Register<App::ScriptReporter>();
    Register<App::ObjectRegistry>();
    Register<App::TweakLoader>(Env::TweakSourceDir());

    Register<App::ArchiveWatcher>(Env::ArchiveHotDir());
    Register<App::ScriptWatcher>(Env::ScriptHotFile());
    Register<App::TweakWatcher>(Env::TweakHotFile());
}
