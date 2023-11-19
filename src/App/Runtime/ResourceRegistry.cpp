#include "ResourceRegistry.hpp"

App::ResourceRegistry::ResourceRegistry(const std::filesystem::path& aMetadataDir)
{
    auto resourceList = aMetadataDir / L"Resources.txt";
    if (std::filesystem::exists(resourceList))
    {
        std::thread([resourceList]() {
            LogInfo("ResourceRegistry: Loading metadata...");

            std::ifstream f(resourceList);
            {
                std::unique_lock _(s_resourcePathLock);
                std::string resourcePath;
                while (std::getline(f, resourcePath))
                {
                    s_resourcePathMap[Red::ResourcePath::HashSanitized(resourcePath.data())] = std::move(resourcePath);
                }
            }

            LogInfo("ResourceRegistry: Loaded {} predefined hashes.", s_resourcePathMap.size());
        }).detach();
    }
}

void App::ResourceRegistry::OnBootstrap()
{
    HookAfter<Raw::ResourcePath::Create>(&OnCreateResourcePath);
    HookAfter<Raw::StreamingSector::Prepare>(&OnStreamingSectorPrepare);
    HookBefore<Raw::StreamingSector::Destruct>(&OnStreamingSectorDestruct);
    HookAfter<Raw::WorldNodeInstance::Initialize>(&OnNodeInstanceInitialize);
}

void App::ResourceRegistry::OnCreateResourcePath(Red::ResourcePath* aPath, const Red::StringView* aPathStr)
{
    if (aPathStr)
    {
        std::unique_lock _(s_resourcePathLock);
        s_resourcePathMap[*aPath] = {aPathStr->data, aPathStr->size};
    }
}

void App::ResourceRegistry::OnStreamingSectorPrepare(Red::worldStreamingSector* aSector, uint64_t)
{
    std::scoped_lock _(s_nodeStaticDataLock, s_nodeInstanceDataLock);
    auto& buffer = Raw::StreamingSector::NodeBuffer::Ref(aSector);
    auto instanceCount = static_cast<uint32_t>(buffer.nodeSetups.end() - buffer.nodeSetups.begin());
    auto nodeCount = buffer.nodes.size;

    for (auto& nodeRef : buffer.nodeRefs)
    {
        auto& nodeRefData = s_nodeRefToStaticDataMap[nodeRef];
        if (!nodeRefData.sectorHash)
        {
            nodeRefData.sectorHash = aSector->path;
        }
    }

    for (auto& nodeSetup : buffer.nodeSetups)
    {
        auto& nodeData = s_nodeSetupToStaticDataMap[&nodeSetup];
        nodeData.sectorHash = aSector->path;
        nodeData.instanceIndex = static_cast<int32_t>(&nodeSetup - buffer.nodeSetups.begin());
        nodeData.instanceCount = instanceCount;
        nodeData.nodeIndex = nodeSetup.nodeIndex;
        nodeData.nodeCount = nodeCount;
        nodeData.nodeID = nodeSetup.globalNodeID;
        nodeData.nodeType = nodeSetup.node->GetType()->GetName();

        if (nodeSetup.globalNodeID)
        {
            s_nodeRefToStaticDataMap[nodeSetup.globalNodeID] = nodeData;
        }

        if (auto communityNode = Red::Cast<Red::worldCompiledCommunityAreaNode>(nodeSetup.node))
        {
            nodeData.nodeID = communityNode->sourceObjectId.hash;
            s_nodeRefToStaticDataMap[nodeData.nodeID] = nodeData;
        }

        s_nodeSetupToRuntimeDataMap[&nodeSetup] = {&nodeSetup, {}, Red::AsWeakHandle(nodeSetup.node)};
    }
}

void App::ResourceRegistry::OnStreamingSectorDestruct(Red::worldStreamingSector* aSector)
{
    std::scoped_lock _(s_nodeStaticDataLock, s_nodeInstanceDataLock);
    auto& buffer = Raw::StreamingSector::NodeBuffer::Ref(aSector);

    size_t erased = 0;
    for (auto& nodeSetup : buffer.nodeSetups)
    {
        if (auto& nodeInstance = s_nodeSetupToRuntimeDataMap[&nodeSetup].nodeInstance)
        {
            s_nodeInstanceToNodeSetupMap.erase(nodeInstance.instance);
        }

        for (const auto& watcher : s_watchers)
        {
            watcher->OnNodeStreamedOut(reinterpret_cast<uint64_t>(&nodeSetup));
        }

        s_nodeSetupToStaticDataMap.erase(&nodeSetup);
        s_nodeSetupToRuntimeDataMap.erase(&nodeSetup);

        ++erased;
    }

#ifndef NDEBUG
    LogInfo("ResourceRegistry: Cleaned up {} tracked nodes.", erased);
#endif
}

void App::ResourceRegistry::OnNodeInstanceInitialize(Red::worldINodeInstance* aNodeInstance,
                                                     Red::CompiledNodeInstanceSetupInfo* aNodeSetup, void*)
{
    std::unique_lock _(s_nodeInstanceDataLock);
    s_nodeSetupToRuntimeDataMap[aNodeSetup].nodeInstance = Red::AsWeakHandle(aNodeInstance);
    s_nodeInstanceToNodeSetupMap[aNodeInstance] = aNodeSetup;

    for (const auto& watcher : s_watchers)
    {
        watcher->OnNodeStreamedIn(reinterpret_cast<uint64_t>(aNodeSetup), aNodeSetup->node, aNodeInstance, aNodeSetup);
    }
}

std::string_view App::ResourceRegistry::ResolveResorcePath(Red::ResourcePath aPath)
{
    if (!aPath)
        return {};

    std::shared_lock _(s_resourcePathLock);
    const auto& it = s_resourcePathMap.find(aPath);

    if (it == s_resourcePathMap.end())
        return {};

    return it.value();
}

App::WorldNodeStaticData App::ResourceRegistry::GetNodeStaticData(Red::CompiledNodeInstanceSetupInfo* aNodeSetup)
{
    if (!aNodeSetup)
        return {};

    std::shared_lock _(s_nodeStaticDataLock);
    const auto& it = s_nodeSetupToStaticDataMap.find(aNodeSetup);

    if (it == s_nodeSetupToStaticDataMap.end())
        return {};

    return it.value();
}

App::WorldNodeStaticData App::ResourceRegistry::GetNodeStaticData(Red::NodeRef aNodeRef)
{
    if (!aNodeRef)
        return {};

    std::shared_lock _(s_nodeStaticDataLock);
    const auto& it = s_nodeRefToStaticDataMap.find(aNodeRef);

    if (it == s_nodeRefToStaticDataMap.end())
        return {};

    return it.value();
}

App::WorldNodeStaticData App::ResourceRegistry::GetNodeStaticData(const Red::WeakHandle<Red::worldINodeInstance>& aNode)
{
    if (!aNode)
        return {};

    std::shared_lock _(s_nodeInstanceDataLock);
    const auto& it = s_nodeInstanceToNodeSetupMap.find(aNode.instance);

    if (it == s_nodeInstanceToNodeSetupMap.end())
        return {};

    return GetNodeStaticData(it.value());
}

App::WorldNodeInstanceData App::ResourceRegistry::GetNodeRuntimeData(Red::CompiledNodeInstanceSetupInfo* aNodeSetup)
{
    if (!aNodeSetup)
        return {};

    std::shared_lock _(s_nodeInstanceDataLock);
    const auto& it = s_nodeSetupToRuntimeDataMap.find(aNodeSetup);

    if (it == s_nodeSetupToRuntimeDataMap.end())
        return {};

    return it.value();
}

App::WorldNodeInstanceData App::ResourceRegistry::GetNodeRuntimeData(
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

Core::Vector<App::WorldNodeInstanceData> App::ResourceRegistry::GetAllStreamedNodes()
{
    Core::Vector<WorldNodeInstanceData> nodes;
    {
        std::shared_lock _(s_nodeInstanceDataLock);
        std::transform(s_nodeSetupToRuntimeDataMap.begin(), s_nodeSetupToRuntimeDataMap.end(),
                       std::back_inserter(nodes), [](auto& v) { return v.second; });
    }
    return nodes;
}

void App::ResourceRegistry::ClearRuntimeData()
{
    {
        std::unique_lock _(s_nodeStaticDataLock);
#ifndef NDEBUG
        LogInfo("ResourceRegistry: Cleaned up {} tracked nodes.", s_nodeSetupToStaticDataMap.size());
#endif
        s_nodeSetupToStaticDataMap.clear();
    }
    {
        std::unique_lock _(s_nodeInstanceDataLock);
        s_nodeSetupToRuntimeDataMap.clear();
        s_nodeInstanceToNodeSetupMap.clear();
    }
}

void App::ResourceRegistry::RegisterWatcher(App::INodeInstanceWatcher* aWatcher)
{
    s_watchers.push_back(aWatcher);
}

void App::ResourceRegistry::UnregisterWatcher(App::INodeInstanceWatcher* aWatcher)
{
    s_watchers.erase(std::remove(s_watchers.begin(), s_watchers.end(), aWatcher), s_watchers.end());
}
