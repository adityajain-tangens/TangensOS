pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// A row of square buttons, each with an icon above its title. It has no background itself.
// List the buttons in `buttons`, like [{ icon: "🔍", title: "Search" }], as many as needed.
Row {
    id: menu

    property var buttons: []
    // Sent with the place of the button in `buttons`
    signal clicked(int index)

    spacing: 8

    Repeater {
        model: menu.buttons

        AbstractButton {
            id: button
            required property var modelData
            required property int index

            width: 96
            height: 96
            // Clicking it leaves the focus where it was, like in a text field
            focusPolicy: Qt.NoFocus
            onClicked: menu.clicked(index)

            background: Rectangle {
                radius: 12
                color: button.down ? "#ebe9e4" : "white"
                border.color: "#dddad3"
            }

            contentItem: Column {
                topPadding: 14
                spacing: 6

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: button.modelData.icon
                    font.pixelSize: 28
                }
                Text {
                    width: parent.width
                    leftPadding: 6
                    rightPadding: 6
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: button.modelData.title
                    color: "#333"
                    font.pixelSize: 12
                }
            }
        }
    }
}
