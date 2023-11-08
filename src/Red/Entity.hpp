#pragma once

namespace Raw::Entity
{
using EntityID = Core::OffsetPtr<0x48, Red::EntityID>;
using ComponentsStorage = Core::OffsetPtr<0x70, Red::ent::ComponentsStorage>;
}
