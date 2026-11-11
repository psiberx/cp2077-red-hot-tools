#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"

namespace App
{
class ScriptReporter
    : public Core::Feature
    , public Core::HookingAgent
    , public Core::LoggingAgent
{
public:
    ScriptReporter() = default;

    void ShowErrorBox(const char* aCaption, const char* aMessage);
    void ShowErrorBox(const char* aCaption, const std::string& aMessage);
    void ShowErrorBox(const char* aCaption, const Red::CString& aMessage);
    void ShowErrorBox(const char* aCaption, const Red::DynArray<Red::CString>& aMessages);

protected:
    void OnBootstrap() override;
    static bool OnLoadScripts(Red::CBaseEngine& aEngine, Red::CString& aPath, uint64_t a3, uint64_t a4);
    static bool OnInvokeSCC(Red::CString& aSourceDir, Red::CString& aBlobPath, uint8_t aProfile, int64_t a4, int32_t a5,
                            int32_t a6, Red::CString* aOutput);

    static bool IsFreshLog(const std::filesystem::path& aPath, auto aCompilationTime);
    static bool ScanForErrorLog(const std::filesystem::path& aPath, std::string& aMessage);
};
}
