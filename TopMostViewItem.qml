pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// The UI in front of everything, even MaximizedViewItem: it fills the window and is always usable.
// Where it has nothing, clicks go through to what's underneath.
Item {
    id: topMost

    signal undoClicked()
    signal redoClicked()

    // Undo and redo, at the bottom left of the window
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 8

        Repeater {
            model: ["↶", "↷"]

            AbstractButton {
                id: button
                required property string modelData
                required property int index

                width: 30
                height: 30
                // Clicking it leaves the focus where it was, like in a text field
                focusPolicy: Qt.NoFocus
                onClicked: index === 0 ? topMost.undoClicked() : topMost.redoClicked()

                background: Rectangle {
                    radius: 6
                    color: button.down ? "#ebe9e4" : "white"
                    border.color: "#dddad3"
                }
                contentItem: Text {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: button.modelData
                    color: "#333"
                    font.pixelSize: 16
                }
            }
        }
    }
}
