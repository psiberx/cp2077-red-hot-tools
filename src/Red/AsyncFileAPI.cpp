#include "AsyncFileAPI.hpp"

Red::AsyncFileAPI* Red::AsyncFileAPI::Get()
{
    return Raw::AsyncFileAPI::Instance;
}

Red::AsyncFileHandleCache* Red::AsyncFileHandleCache::Get()
{
    return Red::AsyncFileAPI::Get()->fileHandleCache;
}

bool Red::AsyncFileHandleCache::CloseSystemHandle(uint32_t aHandle)
{
    auto& file = files[aHandle];
    auto& path = paths[aHandle];

    if (!file.handle || *file.handle == INVALID_HANDLE_VALUE || !path[0])
        return false;

    auto success = CloseHandle(*file.handle);
    *file.handle = INVALID_HANDLE_VALUE;

    return success;
}

bool Red::AsyncFileHandleCache::ReopenSystemHandle(uint32_t aHandle)
{
    auto& file = files[aHandle];
    auto& path = paths[aHandle];

    if (!file.handle || *file.handle != INVALID_HANDLE_VALUE || !path[0])
        return false;

    auto systemFlags = (0xF * (file.flags & 0x4)) | (((file.flags & 0x8) == 0) ? 0x21 : 0xA1);
    auto success = Raw::AsyncFileAPI::OpenSystemHandle(file.handle, path, systemFlags);

    return success;
}

bool Red::AsyncFileHandleCache::UpdateSystemHandle(uint32_t aHandle, uint32_t aNewHandle)
{
    auto& file = files[aHandle];
    auto& path = paths[aHandle];

    if (!file.handle || *file.handle != INVALID_HANDLE_VALUE || !path[0])
        return false;

    auto& newFile = files[aNewHandle];
    auto& newPath = paths[aNewHandle];

    if (!newFile.handle || *newFile.handle == INVALID_HANDLE_VALUE || !newPath[0] || strcmp(path, newPath) != 0)
        return false;

    auto allocator = Red::Memory::EngineAllocator::Get();
    allocator->Free(file.handle);

    file.handle = newFile.handle;

    files[aNewHandle] = {};
    paths[aNewHandle][0] = 0;

    return true;
}
