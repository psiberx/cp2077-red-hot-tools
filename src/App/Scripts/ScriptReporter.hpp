#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"

namespace App
{
class ScriptReporter
    : public Core::Feature
    , public Core::HookingAgent
{
public:
    void ShowErrorBox(const char* aCaption, const char* aMessage);
    void ShowErrorBox(const char* aCaption, const std::string& aMessage);
    void ShowErrorBox(const char* aCaption, const Red::CString& aMessage);
    void ShowErrorBox(const char* aCaption, const Red::DynArray<Red::CString>& aMessages);

protected:
    void OnBootstrap() override;
    bool OnLoadScripts(Red::CBaseEngine& aEngine, Red::CString& aPath, uint64_t a3, uint64_t a4);
};
}
