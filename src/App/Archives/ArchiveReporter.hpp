#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"

namespace App
{
class ArchiveReporter
    : public Core::Feature
    , public Core::HookingAgent
    , public Core::LoggingAgent
{
protected:
    void OnBootstrap() override;
    static void OnRequestResource(Red::ResourceDepot* aDepot, uintptr_t* aHandle, Red::ResourcePath aPath, uintptr_t);
};
}
