#include "RED4extProvider.hpp"

Vendor::RED4extProvider::RED4extProvider(RED4ext::PluginHandle aPlugin, const RED4ext::Sdk* aSdk) noexcept
    : m_plugin(aPlugin)
    , m_sdk(aSdk)
    , m_logging(false)
    , m_hooking(false)
{
}

void Vendor::RED4extProvider::OnInitialize()
{
    if (m_logging)
    {
        LoggingDriver::SetDefault(*this);
    }

    if (m_hooking)
    {
        HookingDriver::SetDefault(*this);
    }
}

void Vendor::RED4extProvider::LogInfo(const std::string& aMessage)
{
    m_sdk->logger->Info(m_plugin, aMessage.c_str());
}

void Vendor::RED4extProvider::LogWarning(const std::string& aMessage)
{
    m_sdk->logger->Warn(m_plugin, aMessage.c_str());
}

void Vendor::RED4extProvider::LogError(const std::string& aMessage)
{
    m_sdk->logger->Error(m_plugin, aMessage.c_str());
}

void Vendor::RED4extProvider::LogDebug(const std::string& aMessage)
{
    m_sdk->logger->Debug(m_plugin, aMessage.c_str());
}

void Vendor::RED4extProvider::LogFlush()
{
}

bool Vendor::RED4extProvider::HookAttach(uintptr_t aAddress, void* aCallback)
{
    return m_sdk->hooking->Attach(m_plugin, reinterpret_cast<void*>(aAddress), aCallback, nullptr);
}

bool Vendor::RED4extProvider::HookAttach(uintptr_t aAddress, void* aCallback, void** aOriginal)
{
    return m_sdk->hooking->Attach(m_plugin, reinterpret_cast<void*>(aAddress), aCallback, aOriginal);
}

bool Vendor::RED4extProvider::HookDetach(uintptr_t aAddress)
{
    return m_sdk->hooking->Detach(m_plugin, reinterpret_cast<void*>(aAddress));
}
