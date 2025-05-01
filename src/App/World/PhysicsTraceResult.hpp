#pragma once

namespace App
{
struct PhysicsTraceResultObject
{
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
    Red::WeakHandle<Red::entEntity> entity;
    Red::WeakHandle<Red::entIComponent> component;
    uint32_t proxyID;
    uint32_t actorIndex;
    uint32_t actorOffset;
    uint32_t shapeIndex;
    float distance;
    uint64_t hash;
    bool resolved;
};

struct PhysicsTraceResulGeometry
{
    Red::Vector4 position;
    Red::Quaternion orientation;
    Red::Box boundingBox;
};
}

RTTI_DEFINE_CLASS(App::PhysicsTraceResultObject, {
    RTTI_PROPERTY(nodeInstance);
    RTTI_PROPERTY(nodeDefinition);
    RTTI_PROPERTY(entity);
    RTTI_PROPERTY(component);
    RTTI_PROPERTY(proxyID);
    RTTI_PROPERTY(actorIndex);
    RTTI_PROPERTY(actorOffset);
    RTTI_PROPERTY(shapeIndex);
    RTTI_PROPERTY(distance);
    RTTI_PROPERTY(hash);
    RTTI_PROPERTY(resolved);
});

RTTI_DEFINE_CLASS(App::PhysicsTraceResulGeometry, {
    RTTI_PROPERTY(position);
    RTTI_PROPERTY(orientation);
    RTTI_PROPERTY(boundingBox);
});
