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

    // True while the top strip is being dragged
    readonly property bool dragging: grab.active

    // Sent while a corner is dragged: which corner, and where the pointer is on screen
    signal resizeStarted()
    signal resizeMoved(bool atLeft, bool atTop, point pointer)

    radius: 12
    color: "white"
    border.color: "#dddad3"
    // In front of the others while dragged
    z: dragging ? 1 : 0

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
    }

    // What's inside: loads the file the model names, like TextFieldItem.qml
    Loader {
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 36
        source: frame.item === "" ? "" : frame.item + ".qml"
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