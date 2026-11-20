pragma ComponentBehavior: Bound

import QtQuick

// First, a grid of the apps open on this Mac to choose from. Once one is chosen, a picture of
// its window fills the whole item instead (AppWindows.mm takes it).
// While maximized, the app's real window is put right over it, the same size, so the app can be used
// as if it were the component. It's put there once the component stops moving or changing size.
// After that, moving or resizing the app's window moves or resizes the component to match.
Item {
    id: snapshot

    // True once an app has been chosen
    property bool chosen: false
    // The chosen app
    property int pid: 0
    // True while the component is maximized. ComponentFrame fills it in.
    property bool interactive: false
    // Shrunk back: a new picture, showing the app as it was left
    onInteractiveChanged: if (!interactive && pid !== 0) apps.capture(pid)

    // Sent when the picture arrives, with its shape (width divided by height), for the component to take
    signal shaped(real aspect)
    // Sent while maximized when the app's window is moved or resized, with where it is now in screen
    // points, for the component to put this item exactly there
    signal screenAreaWanted(rect area)

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
                    snapshot.pid = app.modelData.pid
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

    // While maximized, checks where this item and the app's window are on screen. Once the item has
    // held still for a moment, the window is put over it, and again each time the item is moved or
    // resized after that. Once it's there, a window moved or resized by hand takes the item with it.
    Timer {
        id: follow
        interval: 100
        repeat: true
        running: snapshot.interactive && snapshot.pid !== 0
        // Where it was at the last check, in screen points
        property rect last
        // True once the window is over it there
        property bool placed: false

        onRunningChanged: placed = false
        onTriggered: {
            const topLeft = snapshot.mapToGlobal(0, 0)
            const now = Qt.rect(Math.round(topLeft.x), Math.round(topLeft.y), Math.round(snapshot.width), Math.round(snapshot.height))
            const same = (a, b) => a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height
            if (placed) {
                const window = apps.windowRect(snapshot.pid)
                if (window.width > 0 && !same(window, now)) {
                    // The window was moved or resized: the item follows, and the window stays put
                    last = window
                    snapshot.screenAreaWanted(window)
                    return
                }
            }
            if (!same(now, last)) {
                last = now
                placed = false
            } else if (!placed) {
                // Only tried once per spot: without the permission, macOS would keep asking
                placed = true
                apps.placeWindow(snapshot.pid, now)
            }
        }
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
