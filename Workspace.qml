pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// The area that holds the components. It lays them out on a grid with no end in any direction,
// and scrolls in every direction. There are always a few empty columns and rows around the
// components on every side. Its layout doesn't depend on the window's size.
Flickable {
    id: workspace

    required property WorkspaceModel components
    property bool showGrid: false
    // The component being dragged, or null when nothing is
    property ComponentFrame movingFrame: null
    // The component the dragged one will join in a grid if let go now, or null
    property ComponentFrame mergeTarget: null
    // The cell the dragged component started from
    property point dragStartCell

    // The items that can go in a grid, and so can be merged by dragging one onto another
    readonly property var mergeable: ["ImageItem", "VideoItem", "PDFItem", "GridItem"]

    // Grid settings, the same as the Electron prototype
    readonly property real columnWidth: 96
    readonly property real rowHeight: 56
    readonly property real gap: 12
    readonly property real padding: 16
    readonly property int spareRows: 15
    readonly property int spareColumns: 15

    readonly property real colStep: columnWidth + gap
    readonly property real rowStep: rowHeight + gap

    // Where the components were when the drag started. While a component is dragged, the space
    // before the first components only grows: if it shrank, the view would snap over and the
    // components would slide out from under the pointer.
    property rect boundsAtDragStart

    // The whole area to draw on: from the left and top margins to the content's end, or the window if that's bigger
    readonly property real areaX: -leftMargin
    readonly property real areaY: -topMargin
    readonly property real areaWidth: Math.max(width, leftMargin + contentWidth)
    readonly property real areaHeight: Math.max(height, topMargin + contentHeight)

    // Grid cells to pixels. Cell (0, 0) is at the top-left, inside the padding.
    // Cells can be negative: those are reached by scrolling into the left and top margins.
    function xFor(col) { return padding + col * colStep }
    function yFor(row) { return padding + row * rowStep }
    // Pixels to the cell they're in
    function colAt(x) { return Math.floor((x - padding) / colStep) }
    function rowAt(y) { return Math.floor((y - padding) / rowStep) }
    function widthFor(cols) { return cols * columnWidth + (cols - 1) * gap }
    function heightFor(rows) { return rows * rowHeight + (rows - 1) * gap }

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

    // While a component is dragged: find the cell nearest its top-left corner,
    // and when that's a new cell, ask the model to move it there.
    // Over a component it can merge with, everything goes back to where it started
    // instead, so that component stays put under the pointer.
    function followDrag(frame) {
        mergeTarget = mergeTargetFor(frame)
        if (mergeTarget !== null) {
            if (frame.col !== dragStartCell.x || frame.row !== dragStartCell.y)
                components.moveComponent(frame.index, dragStartCell.x, dragStartCell.y)
            return
        }
        const col = Math.round((frame.x - padding) / colStep)
        const row = Math.round((frame.y - padding) / rowStep)
        if (col !== frame.col || row !== frame.row)
            components.moveComponent(frame.index, col, row)
    }

    // While a corner is dragged: put that corner on the grid line nearest the pointer.
    // The other two edges stay where they are.
    function followResize(frame, atLeft, atTop, pointer) {
        const spot = componentLayer.mapFromItem(null, pointer.x, pointer.y)
        const colLine = Math.round((spot.x - padding + gap / 2) / colStep)
        const rowLine = Math.round((spot.y - padding + gap / 2) / rowStep)

        const left = atLeft ? colLine : frame.col
        const right = atLeft ? frame.col + frame.cols : colLine
        const top = atTop ? rowLine : frame.row
        const bottom = atTop ? frame.row + frame.rows : rowLine
        components.resizeComponent(frame.index, left, top, right, bottom)
    }

    // Scrolls from the first components to the last, plus a few empty columns and rows on every side.
    // The margins reach the cells before the first components, so they're negative when those are after cell 0.
    leftMargin: (spareColumns - (movingFrame !== null ? Math.min(components.bounds.x, boundsAtDragStart.x) : components.bounds.x)) * colStep
    topMargin: (spareRows - (movingFrame !== null ? Math.min(components.bounds.y, boundsAtDragStart.y) : components.bounds.y)) * rowStep
    contentWidth: xFor(components.bounds.x + components.bounds.width + spareColumns) - gap + padding
    contentHeight: yFor(components.bounds.y + components.bounds.height + spareRows) - gap + padding
    // Start with the first components at the top-left, the empty columns and rows before them scrolled out of view
    Component.onCompleted: {
        contentX = xFor(components.bounds.x) - padding
        contentY = yFor(components.bounds.y) - padding
    }
    flickableDirection: Flickable.HorizontalAndVerticalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    ScrollBar.vertical: ScrollBar {}
    ScrollBar.horizontal: ScrollBar {}

    // The background, drawn behind everything
    Rectangle {
        x: workspace.areaX
        y: workspace.areaY
        width: workspace.areaWidth
        height: workspace.areaHeight
        color: "#f2f1ee"
    }

    // The grid lines: one stripe per column and one per row, only while showGrid is on
    Item {
        visible: workspace.showGrid
        x: workspace.areaX
        y: workspace.areaY
        width: workspace.areaWidth
        height: workspace.areaHeight

        Repeater {
            model: Math.ceil(parent.width / workspace.colStep) + 1
            Rectangle {
                required property int index
                x: workspace.xFor(workspace.colAt(workspace.areaX) + index) - workspace.areaX
                width: workspace.columnWidth
                height: parent.height
                color: "#140000ff"
            }
        }
        Repeater {
            model: Math.ceil(parent.height / workspace.rowStep) + 1
            Rectangle {
                required property int index
                y: workspace.yFor(workspace.rowAt(workspace.areaY) + index) - workspace.areaY
                width: parent.width
                height: workspace.rowHeight
                color: "#140000ff"
            }
        }
    }

    // Where the dragged component will land, shown under it while dragging
    Rectangle {
        visible: workspace.movingFrame !== null && workspace.mergeTarget === null
        x: visible ? workspace.xFor(workspace.movingFrame.col) : 0
        y: visible ? workspace.yFor(workspace.movingFrame.row) : 0
        width: visible ? workspace.widthFor(workspace.movingFrame.cols) : 0
        height: visible ? workspace.heightFor(workspace.movingFrame.rows) : 0
        radius: 12
        color: "#145b5bd6"
        border.color: "#5b5bd6"
        border.width: 2
    }

    // A file dragged out of a grid and let go: if that's an empty spot, it becomes a component there
    // and leaves the grid. A grid left with one file becomes a component showing just that file.
    function takeOutOfGrid(frame, file, scenePosition) {
        const spot = componentLayer.mapFromItem(null, scenePosition.x, scenePosition.y)
        if (componentLayer.childAt(spot.x, spot.y) !== null)
            return
        const col = colAt(spot.x)
        const row = rowAt(spot.y)
        const itemFor = (name) => dropArea.itemFor[name.split(".").pop().toLowerCase()]
        if (!components.addComponent(itemFor(file), file, col, row, 4, 6))
            return

        const left = frame.file.split("\n")
        left.splice(left.indexOf(file), 1)
        if (left.length === 1)
            components.replaceItem(frame.index, itemFor(left[0]), left[0])
        else
            components.replaceItem(frame.index, "GridItem", left.join("\n"))
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

            const col = workspace.colAt(spot.x)
            const row = workspace.rowAt(spot.y)
            // New components are 4 columns wide and 6 rows tall
            if (workspace.components.addComponent(item, file, col, row, 4, 6))
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
    }

    Component {
        id: promptMaker
        EmptySpacePromptItem {
            id: prompt

            // Adds a component holding this item where the prompt is, and the prompt goes away
            function addHere(item, text) {
                const col = workspace.colAt(prompt.x)
                const row = workspace.rowAt(prompt.y)
                if (workspace.components.addComponent(item, "", col, row, 4, 6, text))
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
                x: workspace.xFor(col)
                y: workspace.yFor(row)
                width: workspace.widthFor(cols)
                height: workspace.heightFor(rows)

                // Outlined while the dragged component would merge into it
                border.color: workspace.mergeTarget === frame ? "#5b5bd6" : "#dddad3"
                border.width: workspace.mergeTarget === frame ? 3 : 1

                onDraggingChanged: {
                    if (dragging) {
                        workspace.components.startChange()
                        workspace.boundsAtDragStart = workspace.components.bounds
                        workspace.movingFrame = frame
                        workspace.dragStartCell = Qt.point(col, row)
                    } else if (workspace.mergeTarget !== null) {
                        // Dropped on a component it can merge with: they become one grid
                        const target = workspace.mergeTarget
                        workspace.mergeTarget = null
                        workspace.movingFrame = null
                        workspace.merge(frame, target)
                    } else {
                        // Dropped: follow its grid cell again, which glides it into place
                        x = Qt.binding(() => workspace.xFor(col))
                        y = Qt.binding(() => workspace.yFor(row))
                        workspace.movingFrame = null
                    }
                }
                onCloseClicked: workspace.components.removeComponent(index)
                onFileDraggedOut: (file, scenePosition) => workspace.takeOutOfGrid(frame, file, scenePosition)
                onResizeStarted: workspace.components.startChange()
                onResizeMoved: (atLeft, atTop, pointer) => workspace.followResize(frame, atLeft, atTop, pointer)
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
