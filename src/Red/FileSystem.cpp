#include "FileSystem.hpp"

Red::FileSystem* Red::FileSystem::Get()
{
    return Raw::FileSystem::Instance;
}

Red::FileHandle::~FileHandle()
{
    Raw::FileSystem::Close(this);
}
