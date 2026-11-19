import QtQuick

// The frame every component sits in. Drag its top strip to move it, or a corner to resize it.
// What sits inside is a ComponentItem, named in the model (see WorkspaceModel.cpp).
Rectangle {
    id: frame

    // Filled in from this component's entry in the model
    required property int index
    required property int col
    required property int row
    required property int cols
    required property int rows
    required property string item
    required property string file
    required property string text

    // True while the top strip is being dragged
    readonly property bool dragging: grab.active
    // Where the pointer is in the window while the top strip is dragged
    readonly property point dragPoint: grab.centroid.scenePosition

    // Sent while a corner is dragged: which corner, and where the pointer is on screen
    signal resizeStarted()
    signal resizeMoved(bool atLeft, bool atTop, point pointer)
    // Sent when the X button in the top strip is clicked
    signal closeClicked()
    // Sent when a file is dragged out of the item inside and let go, like from a GridItem
    signal fileDraggedOut(string file, point scenePosition)

    radius: 12
    color: "white"
    border.color: "#dddad3"
    // In front of the others while it, or something in it, is dragged
    z: dragging || (content.item?.dragging ?? false) ? 1 : 0

    // When its position changes because of the grid, glide there instead of jumping
    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // The top strip: hold it to drag the whole frame
    Item {
        width: parent.width
        height: 36

        DragHandler {
            id: grab
            target: frame
        }

        // Taking the focus closes an empty "Start typing..." field (EmptySpacePromptItem)
        TapHandler {
            onTapped: frame.forceActiveFocus()
        }

        // The X button on the right: deletes this component
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"
            color: closeHover.hovered ? "#222" : "#888"
            font.pixelSize: 14

            HoverHandler {
                id: closeHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: frame.closeClicked()
            }
        }
    }

    onDraggingChanged: if (dragging) forceActiveFocus()

    // What's inside: loads the file the model names, like TextFieldItem.qml
    Loader {
        id: content
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 36
        source: frame.item === "" ? "" : frame.item + ".qml"
        // Items that show a file, like ImageItem, follow this component's file. It's a binding, not a
        // one-time copy, because when a DropZoneItem is swapped for one (WorkspaceModel::replaceItem),
        // the new item loads before the file arrives.
        // Items that hold text, like TextFieldItem, start with this component's text.
        onLoaded: {
            if ("file" in item) item.file = Qt.binding(() => frame.file)
            if ("text" in item) item.text = frame.text
            if ("draggedOut" in item) item.draggedOut.connect(frame.fileDraggedOut)
        }
    }

    // When it has nothing inside, a different pale colour per component, so they're easy to tell apart
    Rectangle {
        visible: frame.item === ""
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 36
        radius: 8
        color: Qt.hsla((frame.index * 0.17) % 1, 0.5, 0.85, 1)
    }

    // Its grid position, to check the layout
    Text {
        x: 12
        y: 10
        text: "col " + frame.col + ", row " + frame.row + "  ·  " + frame.cols + " × " + frame.rows
        color: "#555"
        font.pixelSize: 13
    }

    // The four corners: invisible squares, centred on each corner, above everything else
    Repeater {
        model: 4
        Item {
            id: corner
            required property int index
            // 0 is top left, 1 top right, 2 bottom left, 3 bottom right
            readonly property bool atLeft: index % 2 === 0
            readonly property bool atTop: index < 2

            width: 16
            height: 16
            x: atLeft ? -width / 2 : frame.width - width / 2
            y: atTop ? -height / 2 : frame.height - height / 2

            // The diagonal resize arrow while the pointer is over it
            HoverHandler {
                cursorShape: corner.atLeft === corner.atTop ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
            }

            DragHandler {
                target: null
                onActiveChanged: if (active) frame.resizeStarted()
                onCentroidChanged: if (active) frame.resizeMoved(corner.atLeft, corner.atTop, centroid.scenePosition)
            }
        }
    }
}