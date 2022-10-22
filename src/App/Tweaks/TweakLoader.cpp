#include "TweakLoader.hpp"

App::TweakLoader::TweakLoader(std::filesystem::path aTweaksDir)
    : m_tweaksDir(aTweaksDir)
{
}

void App::TweakLoader::ReloadTweaks()
{
    Red::ExecuteFunction("TweakXL", "ImportAll", nullptr);
}

void App::TweakLoader::ReloadTweaks(const std::vector<std::filesystem::path>& aPaths)
{
    if (aPaths.empty())
    {
        ReloadTweaks();
        return;
    }

    std::error_code error;

    for (const auto& path : aPaths)
    {
        const auto tweakPath = m_tweaksDir / path;

        if (std::filesystem::exists(tweakPath, error))
        {
            auto tweakPathStr = Red::CString(tweakPath.string().c_str());

            if (std::filesystem::is_directory(tweakPath, error))
            {
                Red::ExecuteFunction("TweakXL", "ImportDir", nullptr, tweakPathStr);
            }
            else
            {
                Red::ExecuteFunction("TweakXL", "Import", nullptr, tweakPathStr);
            }
        }
    }
}
