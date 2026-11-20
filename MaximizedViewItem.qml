pragma ComponentBehavior: Bound

import QtQuick

// Shows components big and usable, in front of the workspace and OverlayView.
// show() moves a component's frame itself in here, out of the workspace, and grows it from where it was.
// The other components are shown small around them (MaximizedComponentsViewItem). Tapping one of those shows
// it here too. They're laid out in rows of two, the last one in the middle when there's an odd number,
// placed like on the workspace: higher ones in higher rows, left ones on the left,
// as big as fits in 80% of the window's width and 90% of its height, each keeping its shape.
// Their corners resize them, like on the workspace, and their top bars move them around the window.
// Clicking outside them shrinks them all back to their places and hands them back to the workspace. Being the
// same frames, they keep everything done to them, like a note's edits or the page a web view is on.
// One resized here takes its new shape in its place on the workspace, keeping about the same size.
Item {
    id: view

    // The workspace the components come from and go back to
    required property Workspace workspace
    // The components shown here, in the order they were shown
    property list<ComponentFrame> frames
    // The ones that were resized here
    property list<ComponentFrame> resizedFrames
    // True while they shrink back
    property bool shrinking: false

    // The shape (width divided by height) of what's inside each shown component, in the same order as frames
    property list<real> aspects

    // Where each shown component sits once grown, in the same order as frames: in rows of two, the last one
    // in the middle when there's an odd number. All rows are as tall as each other, as tall as fits 80% of
    // the window's width and 90% of its height, with 20 pixels between them. Each keeps the shape of
    // what's inside, with its top bar and margins added around it.
    readonly property list<rect> layout: {
        const gap = 20
        const chrome = frames.length > 0 ? frames[0].chrome : Qt.size(0, 0)
        const rows = []
        for (let i = 0; i < aspects.length; i += 2)
            rows.push(aspects.slice(i, i + 2))
        const sum = (row) => row.reduce((a, b) => a + b, 0)
        // How tall what's inside is, in every row
        let inside = (height * 0.9 - gap * (rows.length - 1)) / rows.length - chrome.height
        for (const row of rows)
            inside = Math.min(inside, (width * 0.8 - gap * (row.length - 1) - chrome.width * row.length) / sum(row))
        const rowHeight = inside + chrome.height
        const top = (height - rowHeight * rows.length - gap * (rows.length - 1)) / 2
        const rects = []
        rows.forEach((row, r) => {
            const rowWidth = inside * sum(row) + chrome.width * row.length + gap * (row.length - 1)
            let x = (width - rowWidth) / 2
            for (const aspect of row) {
                const frameWidth = inside * aspect + chrome.width
                rects.push(Qt.rect(x, top + r * (rowHeight + gap), frameWidth, rowHeight))
                x += frameWidth + gap
            }
        })
        return rects
    }

    // Shows this component here too, growing from `from` in this item's coordinates:
    // its thumbnail, or where it's drawn on the workspace when not given
    function show(component, from) {
        if (shrinking)
            return
        from = from ?? workspace.areaIn(component, view)
        component.maximized = true
        component.parent = view
        component.x = from.x
        component.y = from.y
        component.width = from.width
        component.height = from.height
        // Placed like on the workspace: the higher ones in the higher rows, and in each row, left to right
        const middle = (f) => Qt.point(f.area.x + f.area.width / 2, f.area.y + f.area.height / 2)
        const byHeight = frames.concat([component]).sort((a, b) => middle(a).y - middle(b).y)
        const ordered = []
        for (let i = 0; i < byHeight.length; i += 2)
            ordered.push(...byHeight.slice(i, i + 2).sort((a, b) => middle(a).x - middle(b).x))
        // Each keeps the shape it has now: the ones already shown even if resized, the new one its shape on the workspace
        aspects = ordered.map(f => f.contentAspect)
        frames = ordered
        glideTo(layout)
    }

    // Gives what's inside a shown component this shape (width divided by height), here and back on the workspace
    function reshape(frame, aspect) {
        const changed = Array.from(aspects)
        changed[frames.indexOf(frame)] = aspect
        aspects = changed
        if (!resizedFrames.includes(frame))
            resizedFrames.push(frame)
        glideTo(layout)
    }

    function hide() {
        if (frames.length === 0 || shrinking)
            return
        shrinking = true
        for (const frame of resizedFrames)
            workspace.reshape(frame, frame.contentAspect)
        glideTo(frames.map(f => workspace.areaIn(f, view)))
    }

    // Moves and sizes each shown component to the rectangle at the same place in `rects`,
    // animated, from wherever it is now
    property list<rect> glideStarts
    property list<rect> glideEnds
    property real glided: 0
    function glideTo(rects) {
        glide.stop()
        glideStarts = frames.map(f => Qt.rect(f.x, f.y, f.width, f.height))
        glideEnds = rects
        glide.start()
    }
    onGlidedChanged: {
        frames.forEach((frame, i) => {
            const from = glideStarts[i], to = glideEnds[i]
            frame.x = from.x + (to.x - from.x) * glided
            frame.y = from.y + (to.y - from.y) * glided
            frame.width = from.width + (to.width - from.width) * glided
            frame.height = from.height + (to.height - from.height) * glided
        })
    }

    NumberAnimation {
        id: glide
        target: view
        property: "glided"
        from: 0
        to: 1
        duration: 250
        easing.type: Easing.OutCubic

        onFinished: {
            if (view.shrinking) {
                // Back in their places: the workspace has them again
                for (const frame of view.frames)
                    view.workspace.takeBack(frame)
                view.frames = []
                view.resizedFrames = []
                view.shrinking = false
            } else {
                // Grown: follow the window's size from now on
                view.frames.forEach((frame, i) => {
                    frame.x = Qt.binding(() => view.layout[i].x)
                    frame.y = Qt.binding(() => view.layout[i].y)
                    frame.width = Qt.binding(() => view.layout[i].width)
                    frame.height = Qt.binding(() => view.layout[i].height)
                })
            }
        }
    }

    // For each shown component: moving it by its top bar or resizing it by a corner.
    // A resized one's corner follows the pointer and the opposite one stays put, never smaller than on the
    // workspace's minimum, nor past the window's edges.
    // From then on it keeps where it was put, and no longer follows the window's size.
    Repeater {
        model: view.frames
        Item {
            id: watcher
            required property ComponentFrame modelData
            // Where it was when the current resize started
            property rect resizeStart

            Connections {
                target: watcher.modelData
                function onReshapeWanted(aspect) {
                    if (!view.shrinking)
                        view.reshape(watcher.modelData, aspect)
                }
                // Put exactly there, like after a resize by its corner
                function onAreaWanted(area) {
                    if (view.shrinking)
                        return
                    glide.stop()
                    const frame = watcher.modelData
                    if (!view.resizedFrames.includes(frame))
                        view.resizedFrames.push(frame)
                    frame.x = area.x
                    frame.y = area.y
                    frame.width = area.width
                    frame.height = area.height
                }
                function onMovingChanged() {
                    if (watcher.modelData.moving && !view.shrinking)
                        glide.stop()
                }
                function onResizeStarted() {
                    glide.stop()
                    const frame = watcher.modelData
                    if (!view.resizedFrames.includes(frame))
                        view.resizedFrames.push(frame)
                    watcher.resizeStart = Qt.rect(frame.x, frame.y, frame.width, frame.height)
                }
                function onResizeMoved(atLeft, atTop, moved) {
                    const start = watcher.resizeStart
                    let left = start.x, top = start.y, right = start.x + start.width, bottom = start.y + start.height
                    if (atLeft)
                        left = Math.max(0, Math.min(left + moved.x, right - 114))
                    else
                        right = Math.min(view.width, Math.max(right + moved.x, left + 114))
                    if (atTop)
                        top = Math.max(0, Math.min(top + moved.y, bottom - 72))
                    else
                        bottom = Math.min(view.height, Math.max(bottom + moved.y, top + 72))
                    const frame = watcher.modelData
                    frame.x = left
                    frame.y = top
                    frame.width = right - left
                    frame.height = bottom - top
                }
            }
        }
    }

    // The other components, small, around them. In front of them, as they can slide over their edges.
    MaximizedComponentsViewItem {
        anchors.fill: parent
        z: 1
        workspace: view.workspace
        frames: view.frames
        // Only once they're done growing, and gone as soon as they start shrinking back. Hidden by opacity,
        // not visible, so it keeps following the pointer to tell when it's near the window's edges.
        opacity: !glide.running && !view.shrinking ? 1 : 0
        onTapped: (component, from) => view.show(component, from)
    }

    // Dims what's behind them while they're shown. Clicks anywhere outside them shrink them back,
    // and nothing behind gets clicks or wheel turns meanwhile.
    Rectangle {
        anchors.fill: parent
        visible: view.frames.length > 0
        color: "black"
        opacity: view.frames.length > 0 && !view.shrinking ? 0.25 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        MouseArea {
            id: outside
            anchors.fill: parent
            onClicked: (mouse) => {
                // Clicks on them that they don't use themselves, like on their top strips, land here too
                const onFrame = view.frames.some(f => f.contains(f.mapFromItem(outside, mouse.x, mouse.y)))
                if (!onFrame)
                    view.hide()
            }
            onWheel: (wheel) => {}
        }
    }
}
