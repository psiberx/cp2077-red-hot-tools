#include "WorldNodeRegistry.hpp"

void App::WorldNodeRegistry::OnBootstrap()
{
    HookBefore<Raw::StreamingSector::PostLoad>(&OnStreamingSectorLoad);
    HookBefore<Raw::StreamingSector::Destruct>(&OnStreamingSectorDestruct);
    HookAfter<Raw::WorldNodeInstance::Initialize>(&OnNodeInstanceInitialize);
    HookAfter<Raw::WorldNodeInstance::Attach>(&OnNodeInstanceAttach);
    HookBefore<Raw::WorldNodeInstance::Detach>(&OnNodeInstanceDetach);
}

void App::WorldNodeRegistry::OnStreamingSectorLoad(Red::worldStreamingSector* aSector, uint64_t)
{
    std::scoped_lock _(s_nodeStaticDataLock, s_nodeInstanceDataLock);
    auto& buffer = Raw::StreamingSector::NodeBuffer::Ref(aSector);
    auto instanceCount = static_cast<uint32_t>(buffer.nodeSetups.end() - buffer.nodeSetups.begin());
    auto nodeCount = buffer.nodes.size;
    auto sectorHash = aSector->path.hash;

    for (auto& nodeRef : buffer.nodeRefs)
    {
        auto& nodeRefData = s_nodeRefToStaticDataMap[nodeRef];
        if (!nodeRefData.sectorHash)
        {
            nodeRefData.sectorHash = sectorHash;
        }
    }

    for (auto& nodeSetup : buffer.nodeSetups)
    {
        auto* nodeDefinition = buffer.nodes[nodeSetup.nodeIndex].instance;

        auto& nodeData = s_nodeSetupToStaticDataMap[&nodeSetup];
        nodeData.sectorHash = sectorHash;
        nodeData.instanceIndex = static_cast<int32_t>(&nodeSetup - buffer.nodeSetups.begin());
        nodeData.instanceCount = instanceCount;
        nodeData.nodeIndex = nodeSetup.nodeIndex;
        nodeData.nodeCount = nodeCount;
        nodeData.nodeType = nodeDefinition->GetType()->GetName();
        nodeData.nodeID = nodeSetup.globalNodeID;
        nodeData.debugName = *reinterpret_cast<Red::CString*>(&nodeDefinition->ref);

        if (nodeData.nodeID)
        {
            s_nodeRefToStaticDataMap[nodeData.nodeID] = nodeData;
        }

        if (auto communityNode = Red::Cast<Red::worldCompiledCommunityAreaNode>(nodeDefinition))
        {
            nodeData.nodeID = communityNode->sourceObjectId.hash;
            s_nodeRefToStaticDataMap[nodeData.nodeID] = nodeData;
        }
        else if (auto communityRegistryNode = Red::Cast<Red::worldCommunityRegistryNode>(nodeDefinition))
        {
            const auto& registryIndex = nodeData.nodeIndex;
            const auto communityCount = communityRegistryNode->communitiesData.size;
            for (auto communityIndex = 0; communityIndex < communityCount; ++communityIndex)
            {
                const auto& communityItem = communityRegistryNode->communitiesData[communityIndex];
                const auto communityId = communityItem.communityId.entityId;

                s_communityStaticDataMap[communityId] = {sectorHash, registryIndex,
                                                         communityIndex, communityCount, communityId};
            }
        }
        else if (auto proxyMeshNode = Red::Cast<Red::worldEntityProxyMeshNode>(nodeDefinition))
        {
            nodeData.parentID = proxyMeshNode->ownerGlobalId.hash;
        }

        s_nodeSetupToRuntimeDataMap[&nodeSetup] = {&nodeSetup, {}, buffer.nodes[nodeSetup.nodeIndex]};
    }

    for (auto& node : buffer.nodes)
    {
        node->ref.instance = node.instance;
        node->ref.refCount = node.refCount;
    }
}

void App::WorldNodeRegistry::OnStreamingSectorDestruct(Red::worldStreamingSector* aSector)
{
    std::scoped_lock _(s_nodeStaticDataLock, s_nodeInstanceDataLock);
    auto& buffer = Raw::StreamingSector::NodeBuffer::Ref(aSector);

    size_t erased = 0;
    for (auto& nodeSetup : buffer.nodeSetups)
    {
        if (auto nodeInstance = s_nodeSetupToRuntimeDataMap[&nodeSetup].nodeInstance.instance)
        {
            const auto& currentNodeSetup = s_nodeInstanceToNodeSetupMap.find(nodeInstance);
            if (currentNodeSetup != s_nodeInstanceToNodeSetupMap.end() && currentNodeSetup.value() == &nodeSetup)
            {
                s_nodeInstanceToNodeSetupMap.erase(currentNodeSetup);
            }
        }

        erased += s_nodeSetupToStaticDataMap.erase(&nodeSetup);
        s_nodeSetupToRuntimeDataMap.erase(&nodeSetup);
    }

#ifndef NDEBUG
    LogInfo("WorldNodeRegistry: Cleaned up {} tracked nodes.", erased);
#endif
}

void App::WorldNodeRegistry::OnNodeInstanceInitialize(Red::worldINodeInstance* aNodeInstance,
                                                     Red::CompiledNodeInstanceSetupInfo* aNodeSetup, void*)
{
    std::unique_lock _(s_nodeInstanceDataLock);
    s_nodeSetupToRuntimeDataMap[aNodeSetup].nodeInstance = Red::AsWeakHandle(aNodeInstance);
    s_nodeInstanceToNodeSetupMap[aNodeInstance] = aNodeSetup;
}

void App::WorldNodeRegistry::OnNodeInstanceAttach(Red::worldINodeInstance* aNodeInstance, void*)
{
    if (s_watchers.empty())
        return;

    if (auto setupInfo = GetNodeSetupInfo(aNodeInstance))
    {
        for (const auto& watcher : s_watchers)
        {
            watcher->OnNodeStreamedIn(reinterpret_cast<uint64_t>(setupInfo), setupInfo->node, aNodeInstance, setupInfo);
        }
    }
}

void App::WorldNodeRegistry::OnNodeInstanceDetach(Red::worldINodeInstance* aNodeInstance, void*)
{
    if (s_watchers.empty())
        return;

    if (auto setupInfo = GetNodeSetupInfo(aNodeInstance))
    {
        for (const auto& watcher : s_watchers)
        {
            watcher->OnNodeStreamedOut(reinterpret_cast<uint64_t>(setupInfo));
        }
    }
}

App::WorldNodeInstanceStaticData App::WorldNodeRegistry::GetNodeStaticData(Red::CompiledNodeInstanceSetupInfo* aNodeSetup)
{
    if (!aNodeSetup)
        return {};

    std::shared_lock _(s_nodeStaticDataLock);
    const auto& it = s_nodeSetupToStaticDataMap.find(aNodeSetup);

    if (it == s_nodeSetupToStaticDataMap.end())
        return {};

    return it.value();
}

App::WorldNodeInstanceStaticData App::WorldNodeRegistry::GetNodeStaticData(Red::NodeRef aNodeRef)
{
    if (!aNodeRef)
        return {};

    std::shared_lock _(s_nodeStaticDataLock);
    const auto& it = s_nodeRefToStaticDataMap.find(aNodeRef);

    if (it == s_nodeRefToStaticDataMap.end())
        return {};

    return it.value();
}

App::WorldNodeInstanceStaticData App::WorldNodeRegistry::GetNodeStaticData(const Red::WeakHandle<Red::worldINodeInstance>& aNode)
{
    if (!aNode)
        return {};

    std::shared_lock _(s_nodeInstanceDataLock);
    const auto& it = s_nodeInstanceToNodeSetupMap.find(aNode.instance);

    if (it == s_nodeInstanceToNodeSetupMap.end())
        return {};

    return GetNodeStaticData(it.value());
}

App::WorldNodeInstanceRuntimeData App::WorldNodeRegistry::GetNodeRuntimeData(Red::CompiledNodeInstanceSetupInfo* aNodeSetup)
{
    if (!aNodeSetup)
        return {};

    std::shared_lock _(s_nodeInstanceDataLock);
    const auto& it = s_nodeSetupToRuntimeDataMap.find(aNodeSetup);

    if (it == s_nodeSetupToRuntimeDataMap.end())
        return {};

    return it.value();
}

App::WorldNodeInstanceRuntimeData App::WorldNodeRegistry::GetNodeRuntimeData(
    const Red::WeakHandle<Red::worldINodeInstance>& aNode)
{
    if (!aNode)
        return {};

    std::shared_lock _(s_nodeInstanceDataLock);
    const auto& it = s_nodeInstanceToNodeSetupMap.find(aNode.instance);

    if (it == s_nodeInstanceToNodeSetupMap.end())
        return {};

    return GetNodeRuntimeData(it.value());
}

Red::CompiledNodeInstanceSetupInfo* App::WorldNodeRegistry::GetNodeSetupInfo(Red::worldINodeInstance* aNodeInstance)
{
    std::shared_lock _(s_nodeInstanceDataLock);
    const auto& it = s_nodeInstanceToNodeSetupMap.find(aNodeInstance);

    if (it == s_nodeInstanceToNodeSetupMap.end())
        return nullptr;

    return it.value();
}

Core::Vector<App::WorldNodeInstanceRuntimeData> App::WorldNodeRegistry::GetAllStreamedNodes()
{
    Core::Vector<WorldNodeInstanceRuntimeData> nodes;
    {
        std::shared_lock _(s_nodeInstanceDataLock);
        std::transform(s_nodeSetupToRuntimeDataMap.begin(), s_nodeSetupToRuntimeDataMap.end(),
                       std::back_inserter(nodes), [](auto& v) { return v.second; });
    }
    return nodes;
}

App::WorldCommunityStaticData App::WorldNodeRegistry::GetCommunityStaticData(uint64_t aCommunityID)
{
    if (!aCommunityID)
        return {};

    std::shared_lock _(s_nodeStaticDataLock);
    const auto& it = s_communityStaticDataMap.find(aCommunityID);

    if (it == s_communityStaticDataMap.end())
        return {};

    return it.value();
}

void App::WorldNodeRegistry::ClearRuntimeData()
{
    {
        std::unique_lock _(s_nodeStaticDataLock);
#ifndef NDEBUG
        LogInfo("WorldNodeRegistry: Cleaned up {} tracked nodes.", s_nodeSetupToStaticDataMap.size());
#endif
        s_nodeSetupToStaticDataMap.clear();
        s_communityStaticDataMap.clear();
    }
    {
        std::unique_lock _(s_nodeInstanceDataLock);
        s_nodeSetupToRuntimeDataMap.clear();
        s_nodeInstanceToNodeSetupMap.clear();
    }
}

void App::WorldNodeRegistry::RegisterWatcher(App::IWorldNodeInstanceWatcher* aWatcher)
{
    s_watchers.push_back(aWatcher);
}

void App::WorldNodeRegistry::UnregisterWatcher(App::IWorldNodeInstanceWatcher* aWatcher)
{
    s_watchers.erase(std::remove(s_watchers.begin(), s_watchers.end(), aWatcher), s_watchers.end());
}

Red::Handle<Red::worldINodeInstance> App::WorldNodeRegistry::FindStreamedNodeInstance(uint64_t aNodeID)
{
    auto nativeNodeRegistry = Red::GetRuntimeSystem<Red::worldNodeInstanceRegistry>();

    Red::Handle<Red::worldINodeInstance> nodeInstance;
    Raw::WorldNodeRegistry::FindNode(nativeNodeRegistry, nodeInstance, aNodeID);

    return nodeInstance;
}
