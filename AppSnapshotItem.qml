pragma ComponentBehavior: Bound

import QtQuick

// First, a grid of the apps open on this Mac to choose from. Once one is chosen, a picture of
// its window fills the whole item instead (AppWindows.mm takes it).
// While maximized, the app's real window is put right over it, the same size, so the app can be used
// as if it were the component. It's put there once the component stops moving or changing size.
// After that, moving or resizing the app's window moves or resizes the component to match.
// The chosen window is saved (see text). When Tangens starts again, it takes a new picture of that same
// window, or goes back to choosing an app if the window has been closed since.
Item {
    id: snapshot

    // True once an app has been chosen
    property bool chosen: false
    // The chosen app
    property int pid: 0
    // The id of its window in the picture, once there is one
    property int windowId: 0
    // The app's name, to make the saved window easy to tell apart
    property string appName
    // True while it's taking a picture of a window it was showing before Tangens started again
    property bool restoring: false
    // True while the component is maximized. ComponentFrame fills it in.
    property bool interactive: false
    // Shrunk back: a new picture, showing the app as it was left
    onInteractiveChanged: if (!interactive && pid !== 0) apps.capture(pid, windowId)

    // The chosen window, saved with the workspace, like {"pid":812,"id":4521,"app":"Safari"}. "" before
    // one is chosen. ComponentFrame fills it in with the saved one when it's loaded.
    property string text
    onTextChanged: {
        if (chosen || text === "")
            return
        // Loaded: take a new picture of the saved window
        const saved = JSON.parse(text)
        restoring = true
        chosen = true
        pid = saved.pid
        windowId = saved.id
        appName = saved.app ?? ""
        apps.capture(pid, windowId)
    }

    // Sent when the picture arrives, with its shape (width divided by height), for the component to take
    signal shaped(real aspect)
    // Sent while maximized when the app's window is moved or resized, with where it is now in screen
    // points, for the component to put this item exactly there
    signal screenAreaWanted(rect area)

    AppWindows {
        id: apps
        onCaptured: (image, windowId) => {
            picture.source = image
            snapshot.restoring = false
            if (windowId === snapshot.windowId)
                return
            snapshot.windowId = windowId
            snapshot.text = JSON.stringify({ pid: snapshot.pid, id: windowId, app: snapshot.appName })
        }
        onFailed: (error) => {
            if (!snapshot.restoring) {
                message.text = error
                return
            }
            // The saved window is gone: choose an app again
            snapshot.restoring = false
            snapshot.chosen = false
            snapshot.pid = 0
            snapshot.windowId = 0
            snapshot.text = ""
        }
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
                    snapshot.appName = app.modelData.name
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
