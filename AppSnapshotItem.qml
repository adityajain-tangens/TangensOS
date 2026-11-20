pragma ComponentBehavior: Bound

import QtQuick

// First, a grid of the apps open on this Mac to choose from. Once one is chosen, a picture of
// its window fills the whole item instead (AppWindows.mm takes it).
Item {
    id: snapshot

    // True once an app has been chosen
    property bool chosen: false

    // Sent when the picture arrives, with its shape (width divided by height), for the component to take
    signal shaped(real aspect)

    AppWindows {
        id: apps
        onCaptured: (image) => picture.source = image
        onFailed: (error) => message.text = error
    }

    // Choosing an app
    Column {
        id: titles
        visible: !snapshot.chosen
        x: 16
        y: 16
        spacing: 2

        Text {
            text: "Choose an app"
            color: "#333"
            font.pixelSize: 18
            font.bold: true
        }
        Text {
            text: "Apps currently open"
            color: "#888"
            font.pixelSize: 12
        }
    }

    GridView {
        visible: !snapshot.chosen
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: titles.y + titles.height + 12
        clip: true
        cellWidth: 88
        cellHeight: 88
        model: apps.openApps()

        delegate: Item {
            id: app
            required property var modelData
            width: 88
            height: 88

            Column {
                anchors.centerIn: parent
                spacing: 4

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48
                    height: 48
                    source: app.modelData.icon
                }
                Text {
                    width: 80
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: app.modelData.name
                    color: "#333"
                    font.pixelSize: 12
                }
            }

            TapHandler {
                onTapped: {
                    snapshot.chosen = true
                    apps.capture(app.modelData.pid)
                }
            }
        }
    }

    // The chosen app's window
    Image {
        id: picture
        visible: snapshot.chosen
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        clip: true
        onStatusChanged: if (status === Image.Ready) snapshot.shaped(implicitWidth / implicitHeight)
    }

    // Why there's no picture, if it couldn't be taken
    Text {
        id: message
        visible: snapshot.chosen && text !== ""
        anchors.centerIn: parent
        width: parent.width - 32
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: "#888"
        font.pixelSize: 12
    }
}
