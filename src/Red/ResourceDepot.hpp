#pragma once

namespace Raw::ResourceDepot
{
constexpr auto LoadArchives = Core::RawFunc<
    /* addr = */ Red::AddressLib::ResourceDepot_LoadArchives,
    /* type = */ void (*)(Red::ResourceDepot* aDepot,
                          Red::ArchiveGroup& aGroup,
                          const Red::DynArray<Red::CString>& aArchivePaths,
                          Red::DynArray<Red::ResourcePath>& aLoadedResourcePaths,
                          bool aMemoryResident)>{};

constexpr auto DestructArchive = Core::RawFunc<
    /* addr = */ Red::AddressLib::ResourceDepot_DestructArchive,
    /* type = */ void (*)(Red::Archive* aArchive)>{};

constexpr auto DestructArchives = Core::RawFunc<
    /* addr = */ Red::AddressLib::ResourceDepot_DestructArchives,
    /* type = */ void (*)(Red::Archive aArchives[], uint32_t aCount)>{};

constexpr auto RequestResource = Core::RawFunc<
    /* addr = */ Red::AddressLib::ResourceDepot_RequestResource,
    /* type = */ uintptr_t* (*)(Red::ResourceDepot* aDepot,
                                const uintptr_t* aOutResourceHandle,
                                Red::ResourcePath aPath,
                                const int32_t* aArchiveHandle)>{};
}
