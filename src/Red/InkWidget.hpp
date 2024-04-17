#pragma once

namespace Raw::inkWidget
{
constexpr auto Draw = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWidget_Draw,
    /* type = */ void (*)(Red::inkWidget*, void*)>();

constexpr auto SpawnFromLibrary = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWidget_SpawnFromLibrary,
    /* type = */ void (*)(Red::Handle<Red::inkWidgetLibraryItemInstance>& aOut,
                          const Red::Handle<Red::inkWidget>& aParent,
                          const Red::Handle<Red::inkWidgetLibraryResource>& aLibrary,
                          Red::CName aItemName)>();
}
