#pragma once

#include "Red/InkWindow.hpp"

namespace Raw::inkLayer
{
constexpr auto GetPointerHandler = Core::RawVFunc<
    /* addr = */ 0x128,
    /* type = */ Red::InkPointerHandler* (Red::inkLayer::*)()>();

constexpr auto AttachLibraryInstance = Core::RawFunc<
    /* addr = */ Red::AddressLib::InkLayer_AttachLibraryInstance,
    /* type = */ void (*)(Red::inkLayer* aLayer,
                          const Red::Handle<Red::inkWidgetLibraryItemInstance>& aInstance,
                          const Red::Handle<Red::inkWidgetLibraryResource>& aLibrary)>();
}
