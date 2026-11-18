pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// The area that holds the components. It lays them out on a grid and scrolls up and down.
Flickable {
    id: workspace

    required property WorkspaceModel components
    property bool showGrid: false
    // The component being dragged, or null when nothing is
    property ComponentFrame movingFrame: null

    // Grid settings, the same as the Electron prototype
    readonly property int columns: 12
    readonly property real rowHeight: 56
    readonly property real gap: 12
    readonly property real padding: 16
    readonly property int spareRows: 3

    // The 12 columns share the width that's left after the padding and gaps
    readonly property real columnWidth: (width - 2 * padding - (columns - 1) * gap) / columns

    // Grid cells to pixels
    function xFor(col) { return padding + col * (columnWidth + gap) }
    function yFor(row) { return padding + row * (rowHeight + gap) }
    function widthFor(cols) { return cols * columnWidth + (cols - 1) * gap }
    function heightFor(rows) { return rows * rowHeight + (rows - 1) * gap }

    // While a component is dragged: find the cell nearest its top-left corner,
    // and when that's a new cell, ask the model to move it there
    function followDrag(frame) {
        const col = Math.round((frame.x - padding) / (columnWidth + gap))
        const row = Math.round((frame.y - padding) / (rowHeight + gap))
        const landingCol = Math.max(0, Math.min(columns - frame.cols, col))
        const landingRow = Math.max(0, row)
        if (landingCol !== frame.col || landingRow !== frame.row)
            components.moveComponent(frame.index, landingCol, landingRow)
    }

    // Scrolls down to the lowest component, plus a few empty rows
    contentHeight: componentLayer.childrenRect.y + componentLayer.childrenRect.height + spareRows * (rowHeight + gap) + padding
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    ScrollBar.vertical: ScrollBar {}

    // The background, drawn behind everything
    Rectangle {
        width: workspace.width
        height: Math.max(workspace.height, workspace.contentHeight)
        color: "#f2f1ee"
    }

    // The grid lines: one stripe per column and one per row, only while showGrid is on
    Item {
        visible: workspace.showGrid
        width: workspace.width
        height: Math.max(workspace.height, workspace.contentHeight)

        Repeater {
            model: workspace.columns
            Rectangle {
                required property int index
                x: workspace.xFor(index)
                width: workspace.columnWidth
                height: parent.height
                color: "#140000ff"
            }
        }
        Repeater {
            model: Math.ceil(parent.height / (workspace.rowHeight + workspace.gap))
            Rectangle {
                required property int index
                y: workspace.yFor(index)
                width: parent.width
                height: workspace.rowHeight
                color: "#140000ff"
            }
        }
    }

    // Where the dragged component will land, shown under it while dragging
    Rectangle {
        visible: workspace.movingFrame !== null
        x: visible ? workspace.xFor(workspace.movingFrame.col) : 0
        y: visible ? workspace.yFor(workspace.movingFrame.row) : 0
        width: visible ? workspace.widthFor(workspace.movingFrame.cols) : 0
        height: visible ? workspace.heightFor(workspace.movingFrame.rows) : 0
        radius: 12
        color: "#145b5bd6"
        border.color: "#5b5bd6"
        border.width: 2
    }

    // Dropping an image file on an empty spot adds a component that shows it
    DropArea {
        width: workspace.width
        height: Math.max(workspace.height, workspace.contentHeight)

        readonly property var imageTypes: ["png", "jpg", "jpeg", "gif", "bmp", "svg", "tif", "tiff", "webp", "ico"]

        // The first dropped file that's an image, or "" if none is
        function imageIn(urls) {
            for (const url of urls) {
                const name = url.toString()
                if (imageTypes.includes(name.split(".").pop().toLowerCase()))
                    return name
            }
            return ""
        }

        onEntered: (drag) => drag.accepted = imageIn(drag.urls) !== ""
        onDropped: (drop) => {
            const col = Math.floor((drop.x - workspace.padding) / (workspace.columnWidth + workspace.gap))
            const row = Math.floor((drop.y - workspace.padding) / (workspace.rowHeight + workspace.gap))
            // New images are 4 columns wide and 6 rows tall
            if (workspace.components.addComponent("ImageItem", imageIn(drop.urls), Math.max(0, Math.min(workspace.columns - 1, col)), Math.max(0, row), 4, 6))
                drop.accept(Qt.CopyAction)
        }
    }

    // The components, one frame for each entry in the model
    Item {
        id: componentLayer
        width: workspace.width

        Repeater {
            model: workspace.components
            ComponentFrame {
                id: frame
                x: workspace.xFor(col)
                y: workspace.yFor(row)
                width: workspace.widthFor(cols)
                height: workspace.heightFor(rows)

                onDraggingChanged: {
                    if (dragging) {
                        workspace.components.startMove()
                        workspace.movingFrame = frame
                    } else {
                        // Dropped: follow its grid cell again, which glides it into place
                        x = Qt.binding(() => workspace.xFor(col))
                        y = Qt.binding(() => workspace.yFor(row))
                        workspace.movingFrame = null
                    }
                }
                onXChanged: if (dragging) workspace.followDrag(frame)
                onYChanged: if (dragging) workspace.followDrag(frame)
            }
        }
    }
}
