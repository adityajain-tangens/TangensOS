pragma ComponentBehavior: Bound

import QtQuick

// A grid of images, videos and PDFs, with space between them. Each file is shown by the
// item for its kind (ImageItem, VideoItem or PDFItem). The files are only shown: they can be dragged,
// but not clicked or scrolled. When interactive, they can be used instead, and not dragged.
// Works inside a component or anywhere else.
Item {
    id: grid

    // The files to show, one URL per line, like "file:///Users/me/a.png\nfile:///Users/me/b.pdf"
    property string file
    // True while one of the files is being dragged
    property bool dragging: false
    // True when the files can be used, like playing a video or scrolling a PDF, instead of dragged
    property bool interactive: false

    // Sent when a file is dragged and let go outside the grid, with where it was let go in the window.
    // The grid doesn't change by itself: Workspace.qml decides what happens.
    signal draggedOut(string file, point scenePosition)

    readonly property var files: file === "" ? [] : file.split("\n")
    readonly property real spacing: 8
    // Tries every number of columns and keeps the one with the largest cells, counting a cell's
    // shorter side. So a wide space puts the files in a row, a tall one in a column, and a
    // squarer one in a grid. Changes as the component is resized.
    readonly property int columns: {
        let best = 1
        let bestSide = 0
        for (let cols = 1; cols <= files.length; ++cols) {
            const rows = Math.ceil(files.length / cols)
            const side = Math.min((width - (cols - 1) * spacing) / cols, (height - (rows - 1) * spacing) / rows)
            if (side > bestSide) {
                best = cols
                bestSide = side
            }
        }
        return best
    }
    readonly property int rows: Math.max(1, Math.ceil(files.length / columns))
    readonly property real cellWidth: (width - (columns - 1) * spacing) / columns
    readonly property real cellHeight: (height - (rows - 1) * spacing) / rows

    // Which item shows each kind of file, by the end of its name
    readonly property var itemFor: ({
        png: "ImageItem", jpg: "ImageItem", jpeg: "ImageItem", gif: "ImageItem", bmp: "ImageItem",
        svg: "ImageItem", tif: "ImageItem", tiff: "ImageItem", webp: "ImageItem", ico: "ImageItem",
        mp4: "VideoItem", mov: "VideoItem", m4v: "VideoItem", webm: "VideoItem", mkv: "VideoItem", avi: "VideoItem",
        pdf: "PDFItem"
    })

    Grid {
        columns: grid.columns
        spacing: grid.spacing

        Repeater {
            model: grid.files

            Item {
                id: cell
                required property string modelData
                readonly property string itemName: grid.itemFor[modelData.split(".").pop().toLowerCase()] ?? ""
                // How far it's been dragged, and where the pointer last was in the window
                property point offset
                property point lastScenePosition

                width: grid.cellWidth
                height: grid.cellHeight
                clip: true

                // The file. Turned off unless interactive, so it gets no clicks or scrolling: a video doesn't play on a click
                Loader {
                    anchors.fill: parent
                    enabled: grid.interactive
                    source: cell.itemName === "" ? "" : cell.itemName + ".qml"
                    onLoaded: item.file = cell.modelData
                }

                // Follows the pointer while dragged, in front of the other files
                transform: Translate { x: cell.offset.x; y: cell.offset.y }
                z: move.active ? 1 : 0
                opacity: move.active ? 0.8 : 1

                // Hold anywhere on a file to drag it
                DragHandler {
                    id: move
                    enabled: !grid.interactive
                    target: null
                    grabPermissions: PointerHandler.CanTakeOverFromAnything

                    onCentroidChanged: {
                        if (!active)
                            return
                        cell.lastScenePosition = centroid.scenePosition
                        cell.offset = Qt.point(centroid.scenePosition.x - centroid.scenePressPosition.x,
                                               centroid.scenePosition.y - centroid.scenePressPosition.y)
                    }
                    onActiveChanged: {
                        grid.dragging = active
                        if (active)
                            return
                        // Let go: back in place, and if that was outside the grid, say so
                        cell.offset = Qt.point(0, 0)
                        const spot = grid.mapFromItem(null, cell.lastScenePosition.x, cell.lastScenePosition.y)
                        if (!grid.contains(spot))
                            grid.draggedOut(cell.modelData, cell.lastScenePosition)
                    }
                }
            }
        }
    }
}
