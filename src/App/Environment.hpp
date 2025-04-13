#pragma once

#include "Core/Facades/Runtime.hpp"

namespace App::Env
{
inline std::filesystem::path GameDir()
{
    return Core::Runtime::GetRootDir();
}

inline std::filesystem::path ArchiveModDir()
{
    return Core::Runtime::GetRootDir() / L"archive" / L"pc" / L"mod";
}

inline std::filesystem::path ArchiveHotDir()
{
    return Core::Runtime::GetRootDir() / L"archive" / L"pc" / L"hot";
}

inline std::filesystem::path ScriptBlobPath()
{
    return Core::Runtime::GetRootDir() / L"r6" / L"cache" / L"final.redscripts";
}

inline std::filesystem::path ScriptSourceDir()
{
    return Core::Runtime::GetRootDir() / L"r6" / L"scripts";
}

inline std::filesystem::path ScriptHotFile()
{
    return Core::Runtime::GetModuleDir() / L".hot-scripts";
}

inline std::filesystem::path TweakSourceDir()
{
    return Core::Runtime::GetRootDir() / L"r6" / L"tweaks";
}

inline std::filesystem::path TweakHotFile()
{
    return Core::Runtime::GetModuleDir() / L".hot-tweaks";
}

inline std::filesystem::path KnownHashesPath()
{
    return Core::Runtime::GetModuleDir() / L"Resources.txt";
}

inline bool IsPrePatch212a()
{
    auto& fileVer = Core::Runtime::GetHost()->GetFileVer();
    auto patchVer = RED4EXT_RUNTIME_2_12_HOTFIX_1;

    if (fileVer.major != patchVer.major)
    {
        return fileVer.major < patchVer.major;
    }

    if (fileVer.minor != patchVer.minor)
    {
        return fileVer.minor < patchVer.minor;
    }

    if (fileVer.build != patchVer.build)
    {
        return fileVer.build < patchVer.build;
    }

    if (fileVer.revision != patchVer.revision)
    {
        return fileVer.revision < patchVer.revision;
    }

    return false;
}
}
