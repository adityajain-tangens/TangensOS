import QtQuick

// Shows one component big and usable, in front of the workspace and OverlayView.
// show() moves the component's frame itself in here, out of the workspace, and grows it from where it was.
// Clicking outside it shrinks it back to its place and hands it back to the workspace. Being the same
// frame, it keeps everything done to it, like a note's edits or the page a web view is on.
Item {
    id: view

    // The workspace the components come from and go back to
    required property Workspace workspace
    // The component shown here, or null when none is
    property ComponentFrame frame: null
    // True while it shrinks back
    property bool shrinking: false

    // The shown component's width divided by its height in the workspace
    property real aspect: 1

    // Where the component sits once grown: as big as fits in 80% of the window's width and 90% of its height,
    // keeping its shape from the workspace, in the middle
    readonly property rect grownRect: {
        const w = Math.min(width * 0.8, height * 0.9 * aspect)
        const h = w / aspect
        return Qt.rect((width - w) / 2, (height - h) / 2, w, h)
    }

    function show(component) {
        if (frame !== null)
            return
        // Moved in here, at the same spot on screen and the same size as it's drawn now
        const from = workspace.areaIn(component, view)
        component.maximized = true
        component.parent = view
        component.x = from.x
        component.y = from.y
        component.width = from.width
        component.height = from.height
        aspect = from.width / from.height
        frame = component
        glideTo(grownRect)
    }

    function hide() {
        if (frame === null || shrinking)
            return
        shrinking = true
        glideTo(workspace.areaIn(frame, view))
    }

    // Moves and sizes the component to this rectangle, animated, from wherever it is now
    function glideTo(rect) {
        glide.stop()
        // Let go of following the window's size (see glide's onFinished), so the animation alone moves it
        frame.x = frame.x
        frame.y = frame.y
        frame.width = frame.width
        frame.height = frame.height
        glideX.to = rect.x
        glideY.to = rect.y
        glideWidth.to = rect.width
        glideHeight.to = rect.height
        glide.start()
    }

    ParallelAnimation {
        id: glide
        NumberAnimation { id: glideX; target: view.frame; property: "x"; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { id: glideY; target: view.frame; property: "y"; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { id: glideWidth; target: view.frame; property: "width"; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { id: glideHeight; target: view.frame; property: "height"; duration: 250; easing.type: Easing.OutCubic }

        onFinished: {
            if (view.shrinking) {
                // Back in its place: the workspace has it again
                view.workspace.takeBack(view.frame)
                view.frame = null
                view.shrinking = false
            } else {
                // Grown: follow the window's size from now on
                view.frame.x = Qt.binding(() => view.grownRect.x)
                view.frame.y = Qt.binding(() => view.grownRect.y)
                view.frame.width = Qt.binding(() => view.grownRect.width)
                view.frame.height = Qt.binding(() => view.grownRect.height)
            }
        }
    }

    // Dims what's behind the component while it's shown. Clicks anywhere outside it shrink it back,
    // and nothing behind gets clicks or wheel turns meanwhile.
    Rectangle {
        anchors.fill: parent
        visible: view.frame !== null
        color: "black"
        opacity: view.frame !== null && !view.shrinking ? 0.25 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        MouseArea {
            id: outside
            anchors.fill: parent
            onClicked: (mouse) => {
                // Clicks on the component that it doesn't use itself, like on its top strip, land here too
                const onFrame = view.frame.contains(view.frame.mapFromItem(outside, mouse.x, mouse.y))
                if (!onFrame)
                    view.hide()
            }
            onWheel: (wheel) => {}
        }
    }
}
