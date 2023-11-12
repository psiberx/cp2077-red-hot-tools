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
    //HookAfter<Raw::WorldNodeInstance::Initialize>(&OnNodeInstanceInitialize);
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
    std::unique_lock _(s_nodeSectorLock);
    auto& buffer = Raw::StreamingSector::NodeBuffer::Ref(aSector);
    auto& nodeCount = buffer.nodes.size;

    for (auto& nodeRef : buffer.nodeRefs)
    {
        auto& nodeRefData = s_nodeRefToSectorMap[nodeRef.hash];
        nodeRefData.sectorHash = aSector->path;
    }

    for (auto& nodeSetup : buffer.nodeSetups)
    {
        const auto& nodePtr = reinterpret_cast<uintptr_t>(nodeSetup.node);

        auto& nodePtrData = s_nodePtrToSectorMap[nodePtr];
        nodePtrData.nodeID = nodeSetup.globalNodeID;
        nodePtrData.nodeType = nodeSetup.node->GetType()->GetName();
        nodePtrData.sectorHash = aSector->path;
        nodePtrData.nodeIndex = nodeSetup.nodeIndex;
        nodePtrData.nodeCount = nodeCount;

        if (nodeSetup.globalNodeID)
        {
            s_nodeRefToSectorMap[nodeSetup.globalNodeID] = nodePtrData;
        }

        s_nodePtrToNodeMap[nodePtr] = {Red::AsWeakHandle(nodeSetup.node), &nodeSetup};
    }

    for (int32_t nodeIndex = 0; nodeIndex < nodeCount; ++nodeIndex)
    {
        const auto& node = buffer.nodes[nodeIndex];
        const auto& nodePtr = reinterpret_cast<uintptr_t>(node.instance);

        auto& nodePtrData = s_nodePtrToSectorMap[nodePtr];
        nodePtrData.nodeType = node->GetType()->GetName();
        nodePtrData.sectorHash = aSector->path;
        nodePtrData.nodeIndex = nodeIndex;
        nodePtrData.nodeCount = nodeCount;

        if (node->GetType()->IsA(Red::GetType<Red::worldCompiledCommunityAreaNode>()))
        {
            auto& nodeID = node.GetPtr<Red::worldCompiledCommunityAreaNode>()->sourceObjectId.hash;
            nodePtrData.nodeID = nodeID;
            s_nodeRefToSectorMap[nodeID] = nodePtrData;
        }
    }
}

void App::ResourceRegistry::OnStreamingSectorDestruct(Red::worldStreamingSector* aSector)
{
    std::unique_lock _(s_nodeSectorLock);
    auto& buffer = Raw::StreamingSector::NodeBuffer::Ref(aSector);

    size_t erased = 0;
    for (const auto& node : buffer.nodes)
    {
        const auto& nodePtr = reinterpret_cast<uintptr_t>(node.instance);
        erased += s_nodePtrToSectorMap.erase(nodePtr);
        s_nodePtrToNodeMap.erase(nodePtr);
    }

#ifndef NDEBUG
    LogInfo("ResourceRegistry: Cleaned up {} tracked nodes.", erased);
#endif
}

void App::ResourceRegistry::OnNodeInstanceInitialize(Red::worldINodeInstance* aNodeInstance, void*, void*)
{
    std::unique_lock _(s_nodeInstanceLock);
    s_nodeInstances.push_back(Red::AsWeakHandle(aNodeInstance));
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

App::WorldNodeStaticData App::ResourceRegistry::GetWorldNodeStaticData(uint64_t aHash)
{
    if (!aHash)
        return {};

    std::shared_lock _(s_nodeSectorLock);
    const auto& it = s_nodeRefToSectorMap.find(aHash);

    if (it == s_nodeRefToSectorMap.end())
        return {};

    return it.value();
}

App::WorldNodeStaticData App::ResourceRegistry::GetWorldNodeStaticData(void* aPtr)
{
    if (!aPtr)
        return {};

    std::shared_lock _(s_nodeSectorLock);
    const auto& it = s_nodePtrToSectorMap.find(reinterpret_cast<uintptr_t>(aPtr));

    if (it == s_nodePtrToSectorMap.end())
        return {};

    return it.value();
}

Core::Vector<App::WorldNodeDynamicData> App::ResourceRegistry::GetStreamedNodes()
{
    Core::Vector<WorldNodeDynamicData> nodes;
    std::shared_lock _(s_nodeSectorLock);
    std::transform(s_nodePtrToNodeMap.begin(), s_nodePtrToNodeMap.end(), std::back_inserter(nodes),
                   [](auto& v) { return v.second; });
    return nodes;
}

Core::Vector<Red::WeakHandle<Red::worldINodeInstance>> App::ResourceRegistry::GetStreamedNodeInstances()
{
    std::unique_lock _(s_nodeInstanceLock);
    auto [b, e] = std::ranges::remove_if(s_nodeInstances, [](auto& x) { return x.Expired(); });
    s_nodeInstances.erase(b, e);
    return s_nodeInstances;
}

void App::ResourceRegistry::ClearRuntimeData()
{
    {
        std::unique_lock _(s_nodeSectorLock);
#ifndef NDEBUG
        LogInfo("ResourceRegistry: Cleaned up {} tracked nodes.", s_nodePtrToSectorMap.size());
#endif
        s_nodePtrToSectorMap.clear();
        s_nodePtrToNodeMap.clear();
    }
    {
        std::unique_lock _(s_nodeInstanceLock);
        s_nodeInstances.clear();
    }
}
