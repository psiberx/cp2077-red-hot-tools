#include "Application.hpp"
#include "App/Archives/ArchiveLoader.hpp"
#include "App/Archives/ArchiveWatcher.hpp"
#include "App/Environment.hpp"
#include "App/Runtime/InkWidgetCollector.hpp"
#include "App/Runtime/ResourceRegistry.hpp"
#include "App/Runtime/WorldNodeRegistry.hpp"
#include "App/Scripts/ObjectRegistry.hpp"
#include "App/Scripts/ScriptLoader.hpp"
#include "App/Scripts/ScriptLogger.hpp"
#include "App/Scripts/ScriptReporter.hpp"
#include "App/Scripts/ScriptWatcher.hpp"
#include "App/Tweaks/TweakLoader.hpp"
#include "App/Tweaks/TweakWatcher.hpp"
#include "Core/Foundation/RuntimeProvider.hpp"
#include "Support/MinHook/MinHookProvider.hpp"
#include "Support/RED4ext/RED4extProvider.hpp"
#include "Support/RedLib/RedLibProvider.hpp"
#include "Support/Spdlog/SpdlogProvider.hpp"

App::Application::Application(HMODULE aHandle, const RED4ext::Sdk* aSdk)
{
    Register<Core::RuntimeProvider>(aHandle)->SetBaseImagePathDepth(2);

    Register<Support::MinHookProvider>();
    Register<Support::SpdlogProvider>()->AppendTimestampToLogName()->CreateRecentLogSymlink();
    Register<Support::RED4extProvider>(aHandle, aSdk)->EnableAddressLibrary();
    Register<Support::RedLibProvider>();

    Register<App::ArchiveLoader>();
    Register<App::ArchiveWatcher>(Env::ArchiveHotDir());

    Register<App::ScriptLoader>(Env::ScriptSourceDir(), Env::ScriptBlobPath());
    Register<App::ScriptWatcher>(Env::ScriptHotFile());
    Register<App::ScriptLogger>();
    Register<App::ScriptReporter>();
    Register<App::ObjectRegistry>();

    Register<App::TweakLoader>(Env::TweakSourceDir());
    Register<App::TweakWatcher>(Env::TweakHotFile());

    Register<App::ResourceRegistry>(Env::MetadataDir());
    Register<App::WorldNodeRegistry>();
    Register<App::InkWidgetCollector>();
}
