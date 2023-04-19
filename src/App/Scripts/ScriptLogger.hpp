#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"
#include "Red/ScriptBundle.hpp"
#include "Red/ScriptReport.hpp"

namespace App
{

class ScriptLogger
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
protected:
    void OnBootstrap() override;

    static void OnLogChannel(void*, Red::CStackFrame* aFrame, void*, void*);
};
}
