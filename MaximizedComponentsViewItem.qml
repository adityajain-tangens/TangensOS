pragma ComponentBehavior: Bound

import QtQuick

// The other components on the workspace, shown small around the maximized one (ComponentSnapshotItem),
// laid out like on the workspace. Part of MaximizedViewItem.
// The biggest one fits in 300 × 300, and the others, and the distances between them, are shrunk by as much.
// They're hidden until the pointer comes within 100 pixels of the window's edges. Then they slide in from the
// side they're on while fading in, and slide back out and fade away when the pointer leaves the edges.
// Shown, the ones past each side of the maximized one sit against that side of the window, 20 pixels in, keeping
// their distances from each other. Only when there are too many to fit beside it do they cover it, by up to 100 pixels.
Item {
    id: others

    required property Workspace workspace
    // The maximized component, or null when none is
    property ComponentFrame frame: null

    // 1 when they're shown, 0 when hidden, and in between while sliding in or out
    property real reveal: nearEdge ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // True while the pointer is within 100 pixels of the window's edges
    readonly property bool nearEdge: edgeHover.hovered
        && (edgeHover.point.position.x < 100 || edgeHover.point.position.x > width - 100
            || edgeHover.point.position.y < 100 || edgeHover.point.position.y > height - 100)

    // The components still on the workspace: every one but the maximized one, which has left it
    readonly property var shown: frame === null ? [] : workspace.frames()

    // How much they're shrunk: the biggest one fits in 300 × 300
    readonly property real shrink: 300 / Math.max(...shown.map(f => Math.max(f.area.width, f.area.height)))

    // Where a component's thumbnail would be if not moved out to the window's sides: shrunk around the
    // maximized one's middle, like on the workspace
    function shrunk(area) {
        const m = frame.area
        return Qt.rect(frame.x + frame.width / 2 + (area.x - (m.x + m.width / 2)) * shrink,
                       frame.y + frame.height / 2 + (area.y - (m.y + m.height / 2)) * shrink,
                       area.width * shrink, area.height * shrink)
    }

    // How far the thumbnails past each side of the maximized one move out from where shrunk() puts them:
    // until the outermost is 20 pixels from the window's edge, or farther when there are too many to fit
    // beside the maximized one, so they cover at most 100 pixels of it
    readonly property var shifts: {
        const none = { left: 0, right: 0, top: 0, bottom: 0 }
        if (frame === null)
            return none
        const m = frame.area
        const past = (test) => shown.filter(f => test(f.area)).map(f => shrunk(f.area))
        const left = past(a => a.x + a.width <= m.x)
        const right = past(a => a.x >= m.x + m.width)
        const top = past(a => a.y + a.height <= m.y)
        const bottom = past(a => a.y >= m.y + m.height)
        const lefts = (rs) => rs.map(r => r.x), rights = (rs) => rs.map(r => r.x + r.width)
        const tops = (rs) => rs.map(r => r.y), bottoms = (rs) => rs.map(r => r.y + r.height)
        return {
            left: left.length === 0 ? 0 : Math.max(Math.min(...lefts(left)) - 20, Math.max(...rights(left)) - (frame.x + 100)),
            right: right.length === 0 ? 0 : Math.max(width - 20 - Math.max(...rights(right)), frame.x + frame.width - 100 - Math.min(...lefts(right))),
            top: top.length === 0 ? 0 : Math.max(Math.min(...tops(top)) - 20, Math.max(...bottoms(top)) - (frame.y + 100)),
            bottom: bottom.length === 0 ? 0 : Math.max(height - 20 - Math.max(...bottoms(bottom)), frame.y + frame.height - 100 - Math.min(...tops(bottom)))
        }
    }

    // Where a component's thumbnail goes: moved out to the sides of the window it's past.
    // While hidden, 100 pixels farther out, where it slides in from.
    function placeOf(area) {
        // Just as the maximized one goes back, before the thumbnails are taken away
        if (frame === null)
            return Qt.rect(0, 0, 0, 0)
        const m = frame.area
        const r = shrunk(area)
        const slide = (1 - reveal) * 100
        if (area.x + area.width <= m.x) r.x -= shifts.left + slide
        else if (area.x >= m.x + m.width) r.x += shifts.right + slide
        if (area.y + area.height <= m.y) r.y -= shifts.top + slide
        else if (area.y >= m.y + m.height) r.y += shifts.bottom + slide
        return r
    }

    HoverHandler {
        id: edgeHover
    }

    Repeater {
        model: others.shown
        ComponentSnapshotItem {
            required property ComponentFrame modelData
            component: modelData
            opacity: others.reveal
            readonly property rect place: others.placeOf(modelData.area)
            x: place.x
            y: place.y
            width: place.width
            height: place.height
        }
    }
}
