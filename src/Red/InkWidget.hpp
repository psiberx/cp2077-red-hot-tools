#pragma once

#include "Red/InkContext.hpp"

namespace Raw::inkWidget
{
using DrawContexts = Core::OffsetPtr<0x1D0, Red::DynArray<Red::inkDrawContext>*>;

constexpr auto Draw = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWidget_Draw,
    /* type = */ void (*)(Red::inkWidget* aWidget, Red::inkWidgetContext& aContext)>();

constexpr auto IsVisible = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWidget_IsVisible,
    /* type = */ bool (*)(Red::inkWidget*)>();

constexpr auto SpawnFromLibrary = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkWidget_SpawnFromLibrary,
    /* type = */ void (*)(Red::Handle<Red::inkWidgetLibraryItemInstance>& aOut,
                          const Red::Handle<Red::inkWidget>& aParent,
                          const Red::Handle<Red::inkWidgetLibraryResource>& aLibrary,
                          Red::CName aItemName)>();
}
