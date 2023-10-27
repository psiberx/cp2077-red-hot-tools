#pragma once

#include "Addresses.hpp"

namespace Raw::ResourceDepot
{
constexpr auto LoadArchives = Core::RawFunc<
    /* addr = */ Red::Addresses::ResourceDepot_LoadArchives,
    /* type = */ void (*)(Red::ResourceDepot* aDepot,
                          Red::ArchiveGroup& aGroup,
                          const Red::DynArray<Red::CString>& aArchivePaths,
                          Red::DynArray<Red::ResourcePath>& aLoadedResourcePaths,
                          bool aMemoryResident)>{};

constexpr auto RequestResource = Core::RawFunc<
    /* addr = */ Red::Addresses::ResourceDepot_RequestResource,
    /* type = */ uintptr_t (*)(Red::ResourceDepot& aDepot, uintptr_t, Red::ResourcePath aPath, uintptr_t)>{};

constexpr auto DestructArchives = Core::RawFunc<
    /* addr = */ Red::Addresses::ResourceDepot_DestructArchives,
    /* type = */ int64_t (*)(Red::Archive aArchives[], uint32_t aCount)>{};
}
