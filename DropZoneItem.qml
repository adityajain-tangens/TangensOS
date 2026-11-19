import QtQuick

// A spot to drop an image, video or PDF onto, with a border around it.
// A file dropped on it takes its place, shown by the item for that kind of file
// (the DropArea in Workspace.qml does this).
Rectangle {
    radius: 8
    color: "transparent"
    border.color: "#c9c5bc"
    border.width: 2

    Text {
        anchors.centerIn: parent
        text: "📥"
        font.pixelSize: 40
    }
}
