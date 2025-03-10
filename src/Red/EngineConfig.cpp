#include "EngineConfig.hpp"

Red::EngineConfigVar* Red::EngineConfigStore::GetVar(const RED4ext::StringView& aGroupPath,
                                                     const RED4ext::StringView& aOption)
{
    return Raw::EngineConfigStore::GetVar(this, aGroupPath, aOption);
}

Red::EngineConfigVar* Red::EngineConfig::GetVar(const RED4ext::StringView& aGroupPath,
                                                const RED4ext::StringView& aVarName)
{
    return Raw::EngineConfigStore::GetVar(store, aGroupPath, aVarName);
}

Red::EngineConfig* Red::EngineConfig::Get()
{
    return Raw::EngineConfig::GetInstance();
}
