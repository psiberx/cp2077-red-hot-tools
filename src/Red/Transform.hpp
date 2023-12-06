#pragma once

#include "Addresses.hpp"

namespace Raw::Transform
{
constexpr auto ApplyToBox = Core::RawFunc<
    /* addr = */ Red::Addresses::Transform_ApplyToBox,
    /* type = */ void* (*)(const Red::Transform& aTransform, Red::Box& aOut, const Red::Box& aBox)>();
}

// namespace Raw::WorldTransform
// {
// constexpr auto ApplyToBox = Core::RawFunc<
//     /* addr = */ 0x14014D910 - Red::Addresses::ImageBase, // FIXME
//     /* type = */ void* (*)(const Red::WorldTransform& aTransform, Red::Box& aOut, const Red::Box& aBox)>();
// }

namespace Red
{
inline void ScaleBox(Box& aBox, const Vector3& aScale)
{
    Red::Vector4 scale{aScale.X, aScale.Y, aScale.Z, 1.0};
    *reinterpret_cast<__m128*>(&aBox.Min) =
        _mm_mul_ps(*reinterpret_cast<__m128*>(&aBox.Min), *reinterpret_cast<__m128*>(&scale));
    *reinterpret_cast<__m128*>(&aBox.Max) =
        _mm_mul_ps(*reinterpret_cast<__m128*>(&aBox.Max), *reinterpret_cast<__m128*>(&scale));
}

inline void TransformBox(Box& aBox, const Transform& aTransform)
{
    Box newBox{};
    Raw::Transform::ApplyToBox(aTransform, newBox, aBox);
    aBox = newBox;
}

// inline void TransformBox(Box& aBox, const WorldTransform& aTransform)
// {
//     Box newBox{};
//     Raw::WorldTransform::ApplyToBox(aTransform, newBox, aBox);
//     aBox = newBox;
// }

inline bool IsValidBox(const Box& aBox)
{
    return aBox.Max.X >= aBox.Min.X && aBox.Max.Y >= aBox.Min.Y && aBox.Max.Z >= aBox.Min.Z;
}

inline bool IsZeroBox(const Box& aBox)
{
    return aBox.Max.X == 0 && aBox.Min.X == 0 &&
           aBox.Max.Y == 0 && aBox.Min.Y == 0 &&
           aBox.Max.Z == 0 && aBox.Min.Z == 0;
}
}
