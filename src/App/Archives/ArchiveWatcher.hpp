#pragma once

#include "App/Foundation/AbstractWatcher.hpp"

namespace App
{
class ArchiveLoader;

class ArchiveWatcher : public AbstractWatcher
{
public:
    ArchiveWatcher(std::filesystem::path aHotDir);

protected:
    bool Filter(const std::filesystem::path& aPath) override;
    bool Process() override;

    std::filesystem::path m_archiveHotDir;
};
}
