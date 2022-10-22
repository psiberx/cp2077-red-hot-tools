#include "ResourceDepot.hpp"
#include "Addresses.hpp"

Red::ResourceDepot* Red::ResourceDepot::Get()
{
    RelocPtr<ResourceDepot*> ptr(Addresses::ResourceDepot);
    return ptr;
}
