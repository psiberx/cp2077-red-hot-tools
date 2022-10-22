#pragma once

#include "App/Foundation/AbstractWatcher.hpp"

namespace App
{
class TweakWatcher : public AbstractWatcher
{
public:
    TweakWatcher(std::filesystem::path aRequestPath);

protected:
    bool Process() override;
    bool Read(std::vector<std::filesystem::path>& aPaths);
    bool CleanUp();

    std::filesystem::path m_requestPath;
};
}
