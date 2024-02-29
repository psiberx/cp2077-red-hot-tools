#pragma once

namespace Red
{
enum FrustumResult
{
    Undefined = 0,
    Outside = 1,
    Intersecting = 2,
    Inside = 3,
};

struct Frustum
{
    static constexpr auto NumberOfPlanes = 6;

    inline FrustumResult Test(const Vector4& aPoint)
    {
        for (auto i = 0; i < NumberOfPlanes; ++i)
        {
            auto v3 = _mm_mul_ps(*reinterpret_cast<const __m128*>(&aPoint), planes[i]);
            auto v4 = _mm_hadd_ps(v3, v3);
            if (_mm_hadd_ps(v4, v4).m128_f32[0] < 0.0)
            {
                return FrustumResult::Outside;
            }
        }

        return FrustumResult::Inside;
    }

    inline FrustumResult Test(const Box& aBox)
    {
        auto result = FrustumResult::Inside;

        const auto& boxMin = *reinterpret_cast<const __m128*>(&aBox.Min);
        const auto& boxMax = *reinterpret_cast<const __m128*>(&aBox.Max);

        for (auto i = 0; i < NumberOfPlanes; ++i)
        {
            auto v24 = _mm_mul_ps(_mm_or_ps(_mm_and_ps(masks[i], boxMax), _mm_andnot_ps(masks[i], boxMin)), planes[i]);
            auto v25 = _mm_mul_ps(_mm_or_ps(_mm_andnot_ps(masks[i], boxMax), _mm_and_ps(masks[i], boxMin)), planes[i]);
            auto v26 = _mm_hadd_ps(v24, v24);
            auto v27 = _mm_hadd_ps(v25, v25);
            auto v28 = _mm_hadd_ps(v27, v27);

            if (_mm_movemask_ps(_mm_xor_ps(_mm_hadd_ps(v26, v26), v28)))
            {
                result = FrustumResult::Intersecting;
            }
            else if (_mm_movemask_ps(v28))
            {
                result = FrustumResult::Outside;
                break;
            }
        }

        return result;
    }

    __m128 planes[NumberOfPlanes]{};
    __m128 masks[NumberOfPlanes]{};
};

struct Camera
{
};
}

namespace Raw::Camera
{
constexpr auto ProjectPoint = Core::RawFunc<
    /* addr = */ Red::AddressLib::Camera_ProjectPoint,
    /* type = */ void* (*)(Red::Camera* aCamera, Red::Vector4& aOut, const Red::Vector3& aPoint)>();
}

namespace Raw::CameraSystem
{
using Camera = Core::OffsetPtr<0x60, Red::Camera>;

constexpr auto GetCameraPosition = Core::RawVFunc<
    /* addr = */ 0x218,
    /* type = */ void* (Red::gameICameraSystem::*)(Red::Vector3& aOut)>();

constexpr auto GetCameraFrustum = Core::RawVFunc<
    /* addr = */ 0x250,
    /* type = */ void (Red::gameICameraSystem::*)(Red::Frustum& aOut)>();

constexpr auto GetCameraForward = Core::RawVFunc<
    /* addr = */ 0x290,
    /* type = */ void* (Red::gameICameraSystem::*)(Red::Vector4& aOut)>();
}
