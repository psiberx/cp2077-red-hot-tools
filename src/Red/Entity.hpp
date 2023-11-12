#pragma once

namespace Raw::Entity
{
using EntityID = Core::OffsetPtr<0x48, Red::EntityID>;
using TemplatePath = Core::OffsetPtr<0x60, Red::ResourcePath>;
using ComponentsStorage = Core::OffsetPtr<0x70, Red::ent::ComponentsStorage>;
}
