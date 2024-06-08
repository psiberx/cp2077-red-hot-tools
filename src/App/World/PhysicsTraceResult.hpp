#pragma once

namespace App
{
struct PhysicsTraceResultObject
{
    Red::WeakHandle<Red::worldINodeInstance> nodeInstance;
    Red::WeakHandle<Red::worldNode> nodeDefinition;
    Red::WeakHandle<Red::entEntity> entity;
    uint64_t hash;
    bool resolved;
};
}

RTTI_DEFINE_CLASS(App::PhysicsTraceResultObject, {
    RTTI_PROPERTY(nodeInstance);
    RTTI_PROPERTY(nodeDefinition);
    RTTI_PROPERTY(entity);
    RTTI_PROPERTY(resolved);
    RTTI_PROPERTY(hash);
});
