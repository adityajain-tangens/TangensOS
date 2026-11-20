pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// The area that holds the components. They can go anywhere on it: it has no end in any direction,
// and is dragged to scroll in every direction. There's always some empty space around the
// components on every side. Its layout doesn't depend on the window's size.
// Pinching the trackpad or turning the mouse wheel zooms between two levels: full size, and half size.
// Two fingers on the trackpad drag it, like the mouse does.
Flickable {
    id: workspace

    required property WorkspaceModel components
    // Sent when a component is clicked, without dragging it. Main.qml shows it maximized
    // (MaximizedViewItem), which takes it off the workspace until it hands it back with takeBack().
    signal componentClicked(ComponentFrame frame)
    // The component being dragged, or null when nothing is
    property ComponentFrame movingFrame: null
    // The component the dragged one will join in a grid if let go now, or null
    property ComponentFrame mergeTarget: null
    // Where the dragged component started from
    property point dragStart

    // The items that can go in a grid, and so can be merged by dragging one onto another
    readonly property var mergeable: ["ImageItem", "VideoItem", "PDFItem", "GridItem"]

    // The empty space kept past the components on the left and right, and on the top and bottom
    readonly property real spareWidth: 961
    readonly property real spareHeight: 646

    // Where the components were when the drag started. While a component is dragged, the space
    // before the first components only grows: if it shrank, the view would snap over and the
    // components would slide out from under the pointer.
    property rect boundsAtDragStart

    // How big everything is drawn: 1 is full size, 0.5 half size, as if seen from farther back.
    // It glides between the two (see zoomTo()).
    property real zoom: 1
    // While zooming: the spot that stays put on screen, in the workspace at full size and in the window
    property point zoomSpot
    property point zoomSpotInWindow

    // How far the space reaches at full size: before (0, 0) on the left and top, and after it on the right and bottom.
    // The spare space past the components on every side. Before (0, 0), it's negative when the first components
    // are far enough after it.
    readonly property real spaceLeft: spareWidth - (movingFrame !== null ? Math.min(components.bounds.x, boundsAtDragStart.x) : components.bounds.x)
    readonly property real spaceTop: spareHeight - (movingFrame !== null ? Math.min(components.bounds.y, boundsAtDragStart.y) : components.bounds.y)
    readonly property real spaceRight: components.bounds.x + components.bounds.width + spareWidth
    readonly property real spaceBottom: components.bounds.y + components.bounds.height + spareHeight

    // The whole area to draw on, at full size: the space, or the window if that's bigger
    readonly property real areaX: -spaceLeft
    readonly property real areaY: -spaceTop
    readonly property real areaWidth: Math.max(width / zoom, spaceLeft + spaceRight)
    readonly property real areaHeight: Math.max(height / zoom, spaceTop + spaceBottom)

    // The other image, video, PDF or grid component under the pointer while this one is dragged, or null
    function mergeTargetFor(frame) {
        if (!mergeable.includes(frame.item))
            return null
        for (const child of componentLayer.children) {
            const other = child as ComponentFrame
            if (other === null || other === frame || !mergeable.includes(other.item))
                continue
            const spot = other.mapFromItem(null, frame.dragPoint.x, frame.dragPoint.y)
            if (other.contains(spot))
                return other
        }
        return null
    }

    // Puts the files of both components in one grid, in place of the target, and removes the dragged one
    function merge(frame, target) {
        const files = target.file.split("\n").concat(frame.file.split("\n"))
        components.replaceItem(target.index, "GridItem", files.join("\n"))
        components.removeComponent(frame.index)
    }

    // While a component is dragged: ask the model to move it to where it's been dragged,
    // which pushes the components in its way aside.
    // Over a component it can merge with, everything goes back to where it started
    // instead, so that component stays put under the pointer.
    function followDrag(frame) {
        mergeTarget = mergeTargetFor(frame)
        const to = mergeTarget !== null ? dragStart : Qt.point(Math.round(frame.x), Math.round(frame.y))
        if (to.x !== frame.area.x || to.y !== frame.area.y)
            components.moveComponent(frame.index, to.x, to.y)
    }

    // While a corner is dragged: move that corner as far as the pointer has moved, at full size.
    // The opposite corner stays where it is.
    function followResize(frame, atLeft, atTop, moved) {
        components.resizeComponent(frame.index, atLeft, atTop, Math.round(moved.x / zoom), Math.round(moved.y / zoom))
    }

    // Zooms to this level (1 or 0.5), keeping the spot at this point in the window where it is
    function zoomTo(level, inWindow) {
        if (level === (zoomGlide.running ? zoomGlide.to : zoom))
            return
        zoomSpotInWindow = inWindow
        zoomSpot = Qt.point((contentX + inWindow.x) / zoom, (contentY + inWindow.y) / zoom)
        zoomGlide.to = level
        zoomGlide.restart()
    }
    NumberAnimation {
        id: zoomGlide
        target: workspace
        property: "zoom"
        duration: 200
        easing.type: Easing.OutCubic
        onFinished: workspace.returnToBounds()
    }
    onZoomChanged: {
        contentX = zoomSpot.x * zoom - zoomSpotInWindow.x
        contentY = zoomSpot.y * zoom - zoomSpotInWindow.y
    }

    // Pinching the trackpad: apart zooms in to full size, together zooms out to half size
    PinchHandler {
        target: null
        onActiveScaleChanged: {
            const inWindow = workspace.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y)
            if (activeScale > 1.05)
                workspace.zoomTo(1, inWindow)
            else if (activeScale < 0.95)
                workspace.zoomTo(0.5, inWindow)
        }
    }

    // Scrolls over the space, at the zoom it's drawn at. The margins reach the space before (0, 0).
    leftMargin: spaceLeft * zoom
    topMargin: spaceTop * zoom
    contentWidth: spaceRight * zoom
    contentHeight: spaceBottom * zoom
    // Start with the first components near the top-left, the empty space before them scrolled out of view
    Component.onCompleted: {
        contentX = components.bounds.x - 16
        contentY = components.bounds.y - 16
    }
    flickableDirection: Flickable.HorizontalAndVerticalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    ScrollBar.vertical: ScrollBar {}
    ScrollBar.horizontal: ScrollBar {}

    // A file dragged out of a grid and let go: if that's an empty spot, it becomes a component there
    // and leaves the grid. A grid left with one file becomes a component showing just that file.
    function takeOutOfGrid(frame, file, scenePosition) {
        const spot = componentLayer.mapFromItem(null, scenePosition.x, scenePosition.y)
        if (componentLayer.childAt(spot.x, spot.y) !== null)
            return
        const itemFor = (name) => dropArea.itemFor[name.split(".").pop().toLowerCase()]
        if (!components.addComponent(itemFor(file), file, spot.x, spot.y))
            return

        const left = frame.file.split("\n")
        left.splice(left.indexOf(file), 1)
        if (left.length === 1)
            components.replaceItem(frame.index, itemFor(left[0]), left[0])
        else
            components.replaceItem(frame.index, "GridItem", left.join("\n"))
    }

    // Where a component's place on the workspace is on screen, in `item`'s coordinates: smaller when zoomed out
    function areaIn(frame, item) {
        const topLeft = componentLayer.mapToItem(item, frame.area.x, frame.area.y)
        const bottomRight = componentLayer.mapToItem(item, frame.area.x + frame.area.width, frame.area.y + frame.area.height)
        return Qt.rect(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y)
    }

    // Makes a component follow its place in the model again, after it was dragged or shown maximized
    function followArea(frame) {
        frame.x = Qt.binding(() => frame.area.x)
        frame.y = Qt.binding(() => frame.area.y)
        frame.width = Qt.binding(() => frame.area.width)
        frame.height = Qt.binding(() => frame.area.height)
    }

    // Puts a component back on the workspace, after MaximizedViewItem showed it maximized
    function takeBack(frame) {
        frame.parent = componentLayer
        followArea(frame)
        frame.maximized = false
    }

    // Everything in the workspace, drawn at the zoom. Inside it, positions are at full size.
    Item {
        id: zoomLayer
        scale: workspace.zoom
        transformOrigin: Item.TopLeft

        // The background, drawn behind everything
        Rectangle {
            x: workspace.areaX
            y: workspace.areaY
            width: workspace.areaWidth
            height: workspace.areaHeight
            color: "#f2f1ee"
        }

        // Dropping an image, video or PDF file on an empty spot adds a component that shows it
        DropArea {
            id: dropArea
            x: workspace.areaX
            y: workspace.areaY
            width: workspace.areaWidth
            height: workspace.areaHeight

            // Which item shows each kind of file, by the end of its name
            readonly property var itemFor: ({
                png: "ImageItem", jpg: "ImageItem", jpeg: "ImageItem", gif: "ImageItem", bmp: "ImageItem",
                svg: "ImageItem", tif: "ImageItem", tiff: "ImageItem", webp: "ImageItem", ico: "ImageItem",
                mp4: "VideoItem", mov: "VideoItem", m4v: "VideoItem", webm: "VideoItem", mkv: "VideoItem", avi: "VideoItem",
                pdf: "PDFItem"
            })

            // The dropped files the workspace can show
            function showable(urls) {
                return Array.from(urls).map(url => url.toString()).filter(name => itemFor[name.split(".").pop().toLowerCase()])
            }

            onEntered: (drag) => drag.accepted = showable(drag.urls).length > 0
            onDropped: (drop) => {
                // Several files go together in a GridItem, one URL per line
                const files = showable(drop.urls)
                const file = files.join("\n")
                const item = files.length > 1 ? "GridItem" : itemFor[file.split(".").pop().toLowerCase()]

                // On a DropZoneItem, the file takes its place
                const spot = dropArea.mapToItem(componentLayer, drop.x, drop.y)
                const frame = componentLayer.childAt(spot.x, spot.y) as ComponentFrame
                if (frame !== null && frame.item === "DropZoneItem") {
                    workspace.components.replaceItem(frame.index, item, file)
                    drop.accept(Qt.CopyAction)
                    return
                }

                if (workspace.components.addComponent(item, file, spot.x, spot.y))
                    drop.accept(Qt.CopyAction)
            }
        }

        // Clicking an empty spot adds a prompt there to start typing in
        MouseArea {
            id: clickArea
            x: workspace.areaX
            y: workspace.areaY
            width: workspace.areaWidth
            height: workspace.areaHeight
            onClicked: (mouse) => {
                const spot = clickArea.mapToItem(componentLayer, mouse.x, mouse.y)
                if (componentLayer.childAt(spot.x, spot.y) !== null)
                    return
                const prompt = promptMaker.createObject(promptLayer, { x: spot.x, y: spot.y }) as EmptySpacePromptItem
                // Put the line being typed on the spot that was clicked
                prompt.y -= prompt.textField.height / 2
                prompt.textField.forceActiveFocus()
            }
            // Turning the mouse wheel, anywhere, as components pass it on: up zooms in to full size, down zooms
            // out to half size. It no longer scrolls: drag the workspace for that.
            // Two fingers on the trackpad still drag the workspace: those come with a scroll phase (begin, update,
            // end), a mouse wheel doesn't. They're passed on to the Flickable, which scrolls by them.
            onWheel: (wheel) => {
                if (wheel.phase !== Qt.NoScrollPhase) {
                    wheel.accepted = false
                    return
                }
                const inWindow = clickArea.mapToItem(workspace, wheel.x, wheel.y)
                if (wheel.angleDelta.y > 0)
                    workspace.zoomTo(1, inWindow)
                else if (wheel.angleDelta.y < 0)
                    workspace.zoomTo(0.5, inWindow)
            }
        }

        Component {
            id: promptMaker
            EmptySpacePromptItem {
                id: prompt

                // Adds a component holding this item where the prompt is, and the prompt goes away
                function addHere(item, text) {
                    if (workspace.components.addComponent(item, "", prompt.x, prompt.y, text))
                        prompt.destroy()
                }

                // A note: a TextFieldItem starting with what was typed. It holds rich text,
                // so the typed text is escaped to stay exactly as it is.
                onAddNote: (text) => addHere("TextFieldItem", text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\n/g, "<br>"))
                // A web page, searching for what was typed, if anything
                onSearchWeb: (text) => addHere("WebViewItem", text)
                // A spot to drop an image, video or PDF onto
                onAddDropZone: addHere("DropZoneItem", "")
            }
        }

        // The components, one frame for each entry in the model
        Item {
            id: componentLayer

            Repeater {
                model: workspace.components
                ComponentFrame {
                    id: frame
                    x: area.x
                    y: area.y
                    width: area.width
                    height: area.height

                    // Outlined while the dragged component would merge into it
                    border.color: workspace.mergeTarget === frame ? "#5b5bd6" : "#dddad3"
                    border.width: workspace.mergeTarget === frame ? 3 : 1

                    onDraggingChanged: {
                        if (dragging) {
                            workspace.components.startChange()
                            workspace.boundsAtDragStart = workspace.components.bounds
                            workspace.movingFrame = frame
                            workspace.dragStart = Qt.point(area.x, area.y)
                        } else if (workspace.mergeTarget !== null) {
                            // Dropped on a component it can merge with: they become one grid
                            const target = workspace.mergeTarget
                            workspace.mergeTarget = null
                            workspace.movingFrame = null
                            workspace.merge(frame, target)
                        } else {
                            // Dropped: follow its place in the model again
                            workspace.followArea(frame)
                            workspace.movingFrame = null
                        }
                    }
                    onCloseClicked: workspace.components.removeComponent(index)
                    onClicked: workspace.componentClicked(frame)
                    onFileDraggedOut: (file, scenePosition) => workspace.takeOutOfGrid(frame, file, scenePosition)
                    onResizeStarted: workspace.components.startChange()
                    onResizeMoved: (atLeft, atTop, moved) => workspace.followResize(frame, atLeft, atTop, moved)
                    onXChanged: if (dragging) workspace.followDrag(frame)
                    onYChanged: if (dragging) workspace.followDrag(frame)
                    // The frame glides behind the pointer, so also check each time the pointer moves
                    onDragPointChanged: if (dragging) workspace.followDrag(frame)
                }
            }
        }

        // The prompts typed onto empty spots, in front of the components
        Item {
            id: promptLayer
        }
    }
}
