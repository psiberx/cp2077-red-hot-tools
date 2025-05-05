#pragma once

namespace Raw::Transform
{
constexpr auto ApplyToBox = Core::RawFunc<
    /* addr = */ Red::AddressLib::Transform_ApplyToBox,
    /* type = */ void* (*)(const Red::Transform& aTransform, Red::Box& aOut, const Red::Box& aBox)>();
}

// namespace Raw::WorldTransform
// {
// constexpr auto ApplyToBox = Core::RawFunc<
//     /* addr = */ 0x14014D910 - Red::AddressLib::ImageBase, // FIXME
//     /* type = */ void* (*)(const Red::WorldTransform& aTransform, Red::Box& aOut, const Red::Box& aBox)>();
// }

namespace Red
{
inline void ScaleBox(Box& aBox, const Vector4& aScale)
{
    aBox.Min = aBox.Min * aScale;
    aBox.Max = aBox.Max * aScale;

    // *reinterpret_cast<__m128*>(&aBox.Min) =
    //     _mm_mul_ps(*reinterpret_cast<__m128*>(&aBox.Min), *reinterpret_cast<const __m128*>(&aScale));
    // *reinterpret_cast<__m128*>(&aBox.Max) =
    //     _mm_mul_ps(*reinterpret_cast<__m128*>(&aBox.Max), *reinterpret_cast<const __m128*>(&aScale));
}

inline void ScaleBox(Box& aBox, const Vector3& aScale)
{
    ScaleBox(aBox, {aScale.X, aScale.Y, aScale.Z, 1.0});
}

inline void ScaleBox(Box& aBox, float aScale)
{
    ScaleBox(aBox, {aScale, aScale, aScale, 1.0});
}

inline void TransformBox(Box& aBox, const Transform& aTransform)
{
    Box newBox{};
    Raw::Transform::ApplyToBox(aTransform, newBox, aBox);
    aBox = newBox;
}

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

inline void CombineBox(Box& aBox, const Box& aOther)
{
    if (IsValidBox(aOther))
    {
        if (!IsValidBox(aBox) || IsZeroBox(aBox))
        {
            aBox = aOther;
        }
        else
        {
            aBox.Min.X = std::min(aBox.Min.X, aOther.Min.X);
            aBox.Min.Y = std::min(aBox.Min.Y, aOther.Min.Y);
            aBox.Min.Z = std::min(aBox.Min.Z, aOther.Min.Z);
            aBox.Max.X = std::max(aBox.Max.X, aOther.Max.X);
            aBox.Max.Y = std::max(aBox.Max.Y, aOther.Max.Y);
            aBox.Max.Z = std::max(aBox.Max.Z, aOther.Max.Z);
        }
    }
}
}
