#pragma once

namespace Red
{
struct AsyncFileHandleCache
{
    static constexpr auto MaxFiles = 65536;
    static constexpr auto MaxPathLength = 512;

    using FilePath = char[MaxPathLength];

    struct FileState
    {
        HANDLE* handle;   // 00
        int32_t refCount; // 08
        uint8_t flags;    // 0C
    };

    virtual ~AsyncFileHandleCache() = 0;
    virtual uint32_t OpenFile(const char* aPath, uint8_t aFlags) = 0;
    virtual void IncFileRef(uint32_t aHandle) = 0;
    virtual void CloseFile(uint32_t aHandle) = 0;

    bool CloseSystemHandle(uint32_t aHandle);
    bool ReopenSystemHandle(uint32_t aHandle);
    bool UpdateSystemHandle(uint32_t aHandle, uint32_t aNewHandle);

    static AsyncFileHandleCache* Get();

    uint64_t unk08;            // 08
    uint64_t unk10;            // 10
    uint64_t unk18;            // 18
    uint64_t unk20;            // 20
    uint64_t unk28;            // 28
    uint64_t unk30;            // 30
    uint64_t unk38;            // 38
    uint32_t unk40;            // 40
    uint32_t unk44;            // 44
    uint64_t unk48;            // 48
    uint8_t unk50;             // 50
    FileState files[MaxFiles]; // 58
    FilePath paths[MaxFiles];  // 100058
    uint64_t unk2100058;       // 2100058
};
RED4EXT_ASSERT_OFFSET(AsyncFileHandleCache, files, 0x58);
RED4EXT_ASSERT_OFFSET(AsyncFileHandleCache, paths, 0x100058);

struct AsyncFileAPI
{
    static AsyncFileAPI* Get();

    uint8_t unk00[0xF0];                   // 00
    AsyncFileHandleCache* fileHandleCache; // F0
};
RED4EXT_ASSERT_OFFSET(AsyncFileAPI, fileHandleCache, 0xF0);
}

namespace Raw::AsyncFileAPI
{
constexpr auto Instance = Core::RawPtr<
    /* addr = */ Red::AddressLib::AsyncFileAPI_Instance,
    /* type = */ Red::AsyncFileAPI>();

constexpr auto OpenSystemHandle = Core::RawFunc<
    /* addr = */ Red::AddressLib::AsyncFileAPI_OpenSystemHandle,
    /* type = */ bool (*)(HANDLE* aHandle, const char* aPath, uint8_t aFlags)>{};

constexpr auto CloseAndFreeSystemHandle = Core::RawFunc<
    /* addr = */ Red::AddressLib::AsyncFileAPI_CloseAndFreeSystemHandle,
    /* type = */ void (*)(HANDLE* aHandle)>{};
}
