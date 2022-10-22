#pragma once

#include "App/Foundation/AbstractWatcher.hpp"

namespace App
{
class ScriptWatcher : public AbstractWatcher
{
public:
    ScriptWatcher(std::filesystem::path aRequestPath);

protected:
    bool Process() override;
    bool CleanUp();

    std::filesystem::path m_requestPath;
};
}
