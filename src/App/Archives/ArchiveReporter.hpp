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
    struct ArchiveInfo
    {
        Red::ArchiveScope scope;
        std::string_view path;
    };

    void OnBootstrap() override;
    static void OnRequestResource(Red::ResourceDepot* aDepot, const uintptr_t* aResourceHandle,
                                  Red::ResourcePath aResourcePath, const int32_t* aArchiveHandle);

    static ArchiveInfo GetArchiveInfo(Red::ResourceDepot* aDepot, const int32_t* aArchiveHandle);
};
}
