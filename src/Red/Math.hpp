#pragma once

namespace Red
{
inline float DistanceSquared(const Vector4& aPoint, const Box& aBox)
{
    float distanceSquared = 0;

    if (aPoint.X < aBox.Min.X)
    {
        distanceSquared += (aBox.Min.X - aPoint.X) * (aBox.Min.X - aPoint.X);
    }
    else if (aPoint.X > aBox.Max.X)
    {
        distanceSquared += (aBox.Max.X - aPoint.X) * (aBox.Max.X - aPoint.X);
    }

    if (aPoint.Y < aBox.Min.Y)
    {
        distanceSquared += (aBox.Min.Y - aPoint.Y) * (aBox.Min.Y - aPoint.Y);
    }
    else if (aPoint.Y > aBox.Max.Y)
    {
        distanceSquared += (aBox.Max.Y - aPoint.Y) * (aBox.Max.Y - aPoint.Y);
    }

    if (aPoint.Z < aBox.Min.Z)
    {
        distanceSquared += (aBox.Min.Z - aPoint.Z) * (aBox.Min.Z - aPoint.Z);
    }
    else if (aPoint.Z > aBox.Max.Z)
    {
        distanceSquared += (aBox.Max.Z - aPoint.Z) * (aBox.Max.Z - aPoint.Z);
    }

    return distanceSquared;
}

inline float Distance(const Vector4& aPoint, const Box& aBox)
{
    return sqrtf(DistanceSquared(aPoint, aBox));
}

inline float Distance(const Vector4& aPoint1, const Vector4& aPoint2)
{
    return sqrtf((aPoint1.X - aPoint2.X) * (aPoint1.X - aPoint2.X) +
                 (aPoint1.Y - aPoint2.Y) * (aPoint1.Y - aPoint2.Y) +
                 (aPoint1.Z - aPoint2.Z) * (aPoint1.Z - aPoint2.Z));
}

inline bool Intersect(const Vector4& aOrigin, const Vector4& aInverseDirection, const Box& aBox,
                      float& tmin, float& tmax)
{
    float tx1 = (aBox.Min.X - aOrigin.X) * aInverseDirection.X;
    float tx2 = (aBox.Max.X - aOrigin.X) * aInverseDirection.X;

    tmin = std::min(tx1, tx2);
    tmax = std::max(tx1, tx2);

    float ty1 = (aBox.Min.Y - aOrigin.Y) * aInverseDirection.Y;
    float ty2 = (aBox.Max.Y - aOrigin.Y) * aInverseDirection.Y;

    tmin = std::max(tmin, std::min(ty1, ty2));
    tmax = std::min(tmax, std::max(ty1, ty2));

    float tz1 = (aBox.Min.Z - aOrigin.Z) * aInverseDirection.Z;
    float tz2 = (aBox.Max.Z - aOrigin.Z) * aInverseDirection.Z;

    tmin = std::max(tmin, std::min(tz1, tz2));
    tmax = std::min(tmax, std::max(tz1, tz2));

    return tmax >= std::max(0.0f, tmin);
}

inline bool Intersect(const Vector4& aOrigin, const Vector4& aInverseDirection, const Box& aBox)
{
    float tmin, tmax;
    return Intersect(aOrigin, aInverseDirection, aBox, tmin, tmax);
}
}
