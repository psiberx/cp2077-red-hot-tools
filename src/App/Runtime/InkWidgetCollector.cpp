#include "InkWidgetCollector.hpp"
#include "Red/InkWidget.hpp"
#include "Red/InkWindow.hpp"

void App::InkWidgetCollector::OnBootstrap()
{
    HookAfter<Raw::InkWidgetLibrary::SpawnFromLocal>(&OnSpawnLocal);
    HookAfter<Raw::InkWidgetLibrary::SpawnFromExternal>(&OnSpawnExternal);
    HookAfter<Raw::InkSpawner::FinishAsyncSpawn>(&OnFinishAsyncSpawn);
    HookAfter<Raw::inkLayer::AttachLibraryInstance>(&OnAttachInstance);

    Hook<Raw::inkWindow::TogglePointerInput>(&OnTogglePointerInput);
    Hook<Raw::inkWidget::Draw>(&OnWidgetDraw);
}

void App::InkWidgetCollector::OnSpawnRoot(Red::inkWidgetLibraryResource* aLibrary,
                                          Red::Handle<Red::inkWidgetLibraryItemInstance>& aInstance)
{
    if (aInstance)
    {
        AddLibraryItemInstanceData(aLibrary, {}, aInstance);
    }
}

void App::InkWidgetCollector::OnSpawnLocal(Red::inkWidgetLibraryResource* aLibrary,
                                           Red::Handle<Red::inkWidgetLibraryItemInstance>& aInstance,
                                           Red::CName aItemName)
{
    if (aInstance)
    {
        AddLibraryItemInstanceData(aLibrary, aItemName, aInstance);
    }
}

void App::InkWidgetCollector::OnSpawnExternal(Red::inkWidgetLibraryResource* aLibrary,
                                              Red::Handle<Red::inkWidgetLibraryItemInstance>& aInstance,
                                              Red::ResourcePath aExternalPath,
                                              Red::CName aItemName)
{
    if (aInstance)
    {
        AddLibraryItemInstanceData(aLibrary, aItemName, aInstance);
    }
}

void App::InkWidgetCollector::OnAsyncSpawnLocal(Red::inkWidgetLibraryResource* aLibrary,
                                                Red::InkSpawningInfo& aSpawningInfo,
                                                Red::CName aItemName,
                                                uint8_t aParam)
{
    if (aSpawningInfo.context)
    {
        aSpawningInfo.context->request->itemName = aItemName;
    }
}

void App::InkWidgetCollector::OnAsyncSpawnExternal(Red::inkWidgetLibraryResource* aLibrary,
                                                   Red::InkSpawningInfo& aSpawningInfo,
                                                   Red::ResourcePath aExternalPath,
                                                   Red::CName aItemName,
                                                   uint8_t aParam)
{
    if (aSpawningInfo.context)
    {
        aSpawningInfo.context->request->itemName = aItemName;
    }
}

void App::InkWidgetCollector::OnFinishAsyncSpawn(Red::InkSpawningContext& aContext,
                                                 Red::Handle<Red::inkWidgetLibraryItemInstance>& aInstance)
{
    if (auto& request = aContext.request)
    {
        AddLibraryItemInstanceData(request->library, request->itemName, aInstance);
    }
}

void App::InkWidgetCollector::OnAttachInstance(Red::inkLayer*,
                                               const Red::Handle<Red::inkWidgetLibraryItemInstance>& aInstance,
                                               const Red::Handle<Red::inkWidgetLibraryResource>& aLibrary)
{
    if (aInstance)
    {
        aInstance->rootWidget->layerProxy->unk48 = GetLibraryItemInstanceData(aInstance->rootWidget);
    }
}

void App::InkWidgetCollector::AddLibraryItemInstanceData(Red::inkWidgetLibraryResource* aLibrary, Red::CName aItemName,
                                                         Red::inkWidgetLibraryItemInstance* aItemInstance)
{
    auto instanceData = Red::MakeHandle<App::InkLibraryItemInstanceData>();

    instanceData->libraryPathHash = aLibrary->path;
    instanceData->libraryItemName = aItemName ? aItemName : "Root";

    if (aItemInstance->gameController)
    {
        instanceData->gameControllerName = aItemInstance->gameController->GetType()->name;
    }

    aItemInstance->rootWidget->userData.PushBack(instanceData);
}

Red::Handle<App::InkLibraryItemInstanceData> App::InkWidgetCollector::GetLibraryItemInstanceData(
    const Red::Handle<Red::inkWidget>& aWidget)
{
    for (auto& userData : aWidget->userData)
    {
        if (const auto& instanceData = Red::Cast<App::InkLibraryItemInstanceData>(userData))
        {
            return instanceData;
        }
    }
    return {};
}

void App::InkWidgetCollector::OnTogglePointerInput(Red::inkWindow* aWindow, bool aEnabled)
{
    Raw::inkWindow::TogglePointerInput(aWindow, true);
}

void App::InkWidgetCollector::OnWidgetDraw(Red::inkWidget* aWidget, void* a2)
{
    bool isLayerAffected = IsLayerAffected(aWidget);
    bool isWidgetAffected = IsWidgetAffected(aWidget);

    if (isLayerAffected)
    {
        aWidget->layerProxy->layer.instance->isInteractive = true;
    }

    if (isWidgetAffected)
    {
        aWidget->isInteractive = true;
    }

    Raw::inkWidget::Draw(aWidget, a2);

    if (isWidgetAffected)
    {
        aWidget->isInteractive = false;
    }

    if (isLayerAffected)
    {
        aWidget->layerProxy->layer.instance->isInteractive = false;
    }
}

bool App::InkWidgetCollector::IsLayerAffected(Red::inkWidget* aWidget)
{
    return aWidget->layerProxy && !aWidget->layerProxy->layer.instance->isInteractive;
}

bool App::InkWidgetCollector::IsWidgetAffected(Red::inkWidget* aWidget)
{
    return !aWidget->isInteractive && !aWidget->GetNativeType()->IsA(Red::GetClass<Red::inkCacheWidget>());
}

Red::DynArray<App::InkLayerExtendedData> App::InkWidgetCollector::CollectLayers()
{
    Red::DynArray<InkLayerExtendedData> layerDataList;

    auto inkSystem = Red::InkSystem::Get();

    for (const auto& layer : inkSystem->GetLayers())
    {
        if (Red::IsInstanceOf<Red::inkWatermarksLayer>(layer))
            continue;

        InkLayerExtendedData layerData;
        layerData.hash = reinterpret_cast<uint64_t>(layer.instance);
        layerData.handle = layer;
        layerData.isActive = layer->active;
        layerData.isInteractive = layer->isInteractive;
        layerData.inputContext = layer->inputContext;

        {
            InkWindowExtendedData windowData;
            windowData.hash = reinterpret_cast<uint64_t>(layer->window.instance);
            windowData.handle = layer->window;

            layerData.windows.PushBack(std::move(windowData));
        }

        if (const auto& hudLayer = Red::Cast<Red::inkHUDLayer>(layer))
        {
            for (const auto& hudEntry : hudLayer->entries)
            {
                if (hudEntry.window)
                {
                    InkWindowExtendedData windowData;
                    windowData.hash = reinterpret_cast<uint64_t>(hudEntry.window.instance);
                    windowData.name = hudEntry.hudEntryName;
                    windowData.slot = hudEntry.slotParams.slotID;
                    windowData.handle = hudEntry.window;

                    layerData.windows.PushBack(std::move(windowData));
                }
            }
        }
        else if (const auto& worldLayer = Red::Cast<Red::inkWorldLayer>(layer))
        {
            if (Red::IsInstanceOf<Red::inkWorldLayer>(inkSystem->activeLayer))
            {
                for (const auto& component : worldLayer->components)
                {
                    auto window = component->GetWindow();
                    if (window)
                    {
                        InkWindowExtendedData windowData;
                        windowData.hash = reinterpret_cast<uint64_t>(window.instance);
                        windowData.handle = window;
                        windowData.entity = Red::ToWeakHandle(component->GetEntityPtr());

                        layerData.windows.PushBack(std::move(windowData));
                    }
                }
            }
        }

        layerDataList.PushBack(std::move(layerData));
    }

    return layerDataList;
}

App::InkWidgetCollectionData App::InkWidgetCollector::CollectHoveredWidgets()
{
    InkWidgetCollectionData collectionData;

    auto inkSystem = Red::InkSystem::Get();
    auto activeLayer = inkSystem->activeLayer.Lock();

    if (!activeLayer)
        return collectionData;

    if (Red::IsInstanceOf<Red::inkWatermarksLayer>(activeLayer))
    {
        for (const auto& layer : inkSystem->GetLayers())
        {
            if (layer != activeLayer && layer->active && layer->isInteractive)
            {
                if (Red::IsInstanceOf<Red::inkWorldLayer>(layer))
                {
                    activeLayer = inkSystem->GetLayer<Red::inkHUDLayer>();
                }
                else
                {
                    activeLayer = layer;
                }
                break;
            }
        }
    }

    collectionData.layerName = activeLayer->GetNativeType()->name;

    CollectHoveredWidgets(collectionData.widgets, inkSystem->pointerScreenPosition, activeLayer->window);

    if (const auto& hudLayer = Red::Cast<Red::inkHUDLayer>(activeLayer))
    {
        for (const auto& hudEntry : hudLayer->entries)
        {
            CollectHoveredWidgets(collectionData.widgets, inkSystem->pointerScreenPosition, hudEntry.window, &hudEntry);
        }
    }
    else if (const auto& worldLayer = Red::Cast<Red::inkWorldLayer>(activeLayer))
    {
        auto pointerHandler = Raw::inkLayer::GetPointerHandler(activeLayer);
        if (pointerHandler)
        {
            if (auto window = pointerHandler->GetActiveWindow().Lock())
            {
                CollectHoveredWidgets(collectionData.widgets, inkSystem->pointerWindowPosition, window);

                for (const auto& component : worldLayer->components)
                {
                    if (window == component->GetWindowPtr())
                    {
                        collectionData.entity = Red::ToWeakHandle(component->GetEntityPtr());
                        break;
                    }
                }
            }
        }
    }

    Core::Set<Red::inkWidget*> parentWidgets;

    for (auto& widgetData : collectionData.widgets)
    {
        auto& widget = widgetData.handle;

        widgetData.layerHash = reinterpret_cast<uint64_t>(activeLayer.instance);
        widgetData.depth = 0;

        if (widget.instance->isInteractive)
        {
            widgetData.isInteractive = true;
        }

        auto parentWidget = widget.instance->parentWidget;
        while (parentWidget)
        {
            ++widgetData.depth;

            if (parentWidget.instance->isInteractive)
            {
                widgetData.isInteractive = true;
            }

            parentWidgets.insert(parentWidget.instance);
            parentWidget = parentWidget.instance->parentWidget;
        }
    }

    for (auto i = static_cast<int32_t>(collectionData.widgets.size) - 1; i >= 0; --i)
    {
        if (parentWidgets.contains(collectionData.widgets[i].handle.instance))
        {
            collectionData.widgets.RemoveAt(i);
        }
    }

    return collectionData;
}

bool App::InkWidgetCollector::CollectHoveredWidgets(Red::DynArray<InkWidgetExtendedData>& aOut,
                                                    const Red::Vector2& aPointerPosition,
                                                    const Red::Handle<Red::inkVirtualWindow>& aWindow,
                                                    const Red::inkHudWidgetSpawnEntry* aHudEntry,
                                                    const Red::entEntity* aEntity)
{
    if (!aWindow)
        return false;

    const auto& pointerHandler = Raw::inkWindow::PointerHandler::Ref(aWindow);

    if (!pointerHandler)
        return false;

    Red::Vector2 pointerScreenPosition{aPointerPosition};
    Red::Vector2 pointerWindowPosition{0.0, 0.0};
    Red::Vector2 pointerSize{10.0, 10.0};

    if (aHudEntry)
    {
        if (!aHudEntry->enabled)
            return false;

        Red::Vector2 slotOffset{};
        Red::Vector2 slotScreenPosition{};

        if (Red::CallStatic("inkWidgetUtils", "LocalToGlobal", slotScreenPosition, aHudEntry->slotWidget, slotOffset))
        {
            pointerScreenPosition.X -= slotScreenPosition.X;
            pointerScreenPosition.Y -= slotScreenPosition.Y;
        }
    }

    Red::DynArray<Red::Handle<Red::inkWidget>> widgets;
    pointerHandler->CollectWidgets(widgets, pointerScreenPosition, pointerWindowPosition, pointerSize);

    auto success = false;

    for (auto& widget : widgets)
    {
        if (Red::IsInstanceOf<Red::inkVirtualWindow>(widget))
            continue;

        if (widget->name == "HUDMiddleWidget" || (widget->parentWidget.instance->name == "HUDMiddleWidget" && widget->size.X == 3840))
            continue;

        if (widget->layerProxy && widget->layerProxy->resource && widget->layerProxy->resource.instance->path == 8110734472173950877ull)
            continue;

        aOut.PushBack({widget, reinterpret_cast<uint64_t>(widget.instance)});

        success = true;
    }

    return success;
}

App::InkWidgetSpawnData App::InkWidgetCollector::GetWidgetSpawnInfo(const Red::Handle<Red::inkWidget>& aWidget)
{
    InkWidgetSpawnData spawnData;

    auto& layerProxy = aWidget->layerProxy;
    if (layerProxy)
    {
        if (const auto& instanceData = Red::Cast<InkLibraryItemInstanceData>(layerProxy->unk48.Lock()))
        {
            spawnData.libraryPathHash = instanceData->libraryPathHash;
            spawnData.libraryItemName = instanceData->libraryItemName;
            spawnData.gameControllerName = instanceData->gameControllerName;
        }
        else if (auto resource = layerProxy->resource.Lock())
        {
            spawnData.libraryPathHash = resource->path.hash;
            spawnData.libraryItemName = "Root";
        }

        if (auto layer = layerProxy->layer.Lock())
        {
            spawnData.layerName = layer->GetNativeType()->name;
            spawnData.inputContext = layer->inputContext;

            if (!spawnData.gameControllerName && layer->libraryItem && layer->libraryItem->gameController)
            {
                spawnData.gameControllerName = layer->libraryItem->gameController->GetType()->name;
            }
        }
    }

    return spawnData;
}

void App::InkWidgetCollector::TogglePointerInput(bool aEnabled)
{
    auto inkSystem = Red::InkSystem::Get();
    auto topLayer = inkSystem->GetLayer<Red::inkWatermarksLayer>();

    if (!topLayer->inputContext)
    {
        auto cursorLibrary = Red::ResourceLoader::Get()->LoadAsync<Red::inkWidgetLibraryResource>(
            R"(base\gameplay\gui\widgets\cursors\default_cursor.inkwidget)");
        Red::WaitForResource(cursorLibrary, std::chrono::milliseconds(1000));

        Red::Handle<Red::inkWidgetLibraryItemInstance> cursor{};
        Raw::inkWidget::SpawnFromLibrary(cursor, topLayer->window, cursorLibrary->resource, "Root");

        if (!cursor)
            return;

        cursor->rootWidget->layout.anchor = Red::inkEAnchor::TopLeft;
        cursor->rootWidget->renderTransform.scale = {1.0, 1.0};

        Raw::inkWindow::SetPointerWidget(topLayer->window, cursor->rootWidget);

        topLayer->inputContext = "UINotifications";
    }

    Raw::inkWindow::SetPointerVisibility(topLayer->window, aEnabled);

    topLayer->isInteractive = aEnabled;
    topLayer->active = aEnabled;
}

void App::InkWidgetCollector::TogglePointerInput()
{
    auto inkSystem = Red::InkSystem::Get();
    auto topLayer = inkSystem->GetLayer<Red::inkWatermarksLayer>();

    TogglePointerInput(!topLayer->isInteractive);
}

void App::InkWidgetCollector::EnsurePointerInput()
{
    auto inkSystem = Red::InkSystem::Get();
    auto activeLayer = inkSystem->activeLayer.Lock();

    if (!activeLayer)
        return;

    if (Red::IsInstanceOf<Red::inkWatermarksLayer>(activeLayer))
        return;

    if (Red::IsInstanceOf<Red::inkWorldLayer>(activeLayer))
    {
        auto pointerHandler = Raw::inkLayer::GetPointerHandler(activeLayer);
        if (pointerHandler && pointerHandler->GetActiveWindow())
            return;
    }
    else
    {
        if (activeLayer->isInteractive && Raw::inkWindow::IsPointerVisible(activeLayer->window))
            return;
    }

    TogglePointerInput(true);
}
