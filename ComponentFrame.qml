import QtQuick

// The frame every component sits in. Drag its top strip to move it.
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

    // True while the top strip is being dragged
    readonly property bool dragging: grab.active

    radius: 12
    color: "white"
    border.color: "#dddad3"
    // In front of the others while dragged
    z: dragging ? 1 : 0

    // When its position changes because of the grid, glide there instead of jumping
    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // The top strip: hold it to drag the whole frame
    Item {
        width: parent.width
        height: 36

        DragHandler {
            id: grab
            target: frame
        }

        // Taking the focus closes an empty "Start typing..." field (EmptySpaceTextFieldItem)
        TapHandler {
            onTapped: frame.forceActiveFocus()
        }
    }

    onDraggingChanged: if (dragging) forceActiveFocus()

    // What's inside: loads the file the model names, like TextFieldItem.qml
    Loader {
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 36
        source: frame.item === "" ? "" : frame.item + ".qml"
        // Items that show a file, like ImageItem, get this component's file
        onLoaded: if ("file" in item) item.file = frame.file
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
}