#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"
#include "Red/ScriptBundle.hpp"
#include "Red/ScriptReport.hpp"


namespace App
{
class ScriptLoader
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    ScriptLoader(std::filesystem::path aSourceDir, std::filesystem::path aCachePath);

    bool CanReloadScripts();
    void ReloadScripts();

protected:
    bool CompileScripts(Red::ScriptBundle& aBundle);
    bool ValidateScripts(Red::ScriptBundle& aBundle, Red::ScriptReport& aReport);
    bool BindScripts(Red::ScriptBundle& aBundle, Red::ScriptReport& aReport);
    void CaptureScriptableData();
    void RestoreScriptableData();

    static bool HasScriptedProperties(Red::CClass* aClass);
    static void ClearScriptedProperties(Red::CClass* aClass);
    static void ShowErrorBox(const char* aCaption, const Red::CString& aMessage);

    std::filesystem::path m_scriptSourceDir;
    std::filesystem::path m_scriptBlobPath;
    std::mutex m_reloadMutex;
};
}
