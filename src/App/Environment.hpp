#pragma once

#include "Core/Facades/Runtime.hpp"

namespace App::Env
{
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
}
