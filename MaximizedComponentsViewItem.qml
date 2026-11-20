pragma ComponentBehavior: Bound

import QtQuick

// The other components on the workspace, shown small around the maximized one (ComponentSnapshotItem),
// laid out like on the workspace. Part of MaximizedViewItem.
// The biggest one fits in 300 × 300, and the others, and the distances between them, are shrunk by as much.
// They're hidden until the pointer comes within 100 pixels of the window's edges. Then they slide in from the
// side they're on while fading in, until the closest one overlaps the maximized one by 100 pixels. The rest keep
// their distances from there. They slide back out and fade away when the pointer leaves the edges.
Item {
    id: others

    required property Workspace workspace
    // The maximized component, or null when none is
    property ComponentFrame frame: null

    // 1 when they're shown, 0 when hidden, and in between while sliding in or out
    property real reveal: nearEdge ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // How far the closest one is from the maximized one's sides: overlapping it by 100 pixels when shown,
    // and 100 pixels farther out when hidden, where they slide in from
    readonly property real gap: -100 + (1 - reveal) * 100

    // True while the pointer is within 100 pixels of the window's edges
    readonly property bool nearEdge: edgeHover.hovered
        && (edgeHover.point.position.x < 100 || edgeHover.point.position.x > width - 100
            || edgeHover.point.position.y < 100 || edgeHover.point.position.y > height - 100)

    // The components still on the workspace: every one but the maximized one, which has left it
    readonly property var shown: frame === null ? [] : workspace.frames()

    // How much they're shrunk: the biggest one fits in 300 × 300
    readonly property real shrink: 300 / Math.max(...shown.map(f => Math.max(f.area.width, f.area.height)))

    // How far each one is from the maximized one on the workspace: along the side it's past, or the
    // farther of the two when it's past a corner
    function distance(area) {
        const m = frame.area
        const dx = Math.max(0, area.x - (m.x + m.width), m.x - (area.x + area.width))
        const dy = Math.max(0, area.y - (m.y + m.height), m.y - (area.y + area.height))
        return Math.max(dx, dy)
    }
    readonly property real closest: Math.min(...shown.map(f => distance(f.area)))

    // Where a component's thumbnail goes, around the maximized one as it's shown now.
    // First shrunk around the maximized one's middle, like on the workspace. Then, on each side the
    // component is past, pushed out to clear the maximized one's real size, plus the gap.
    function placeOf(area) {
        // Just as the maximized one goes back, before the thumbnails are taken away
        if (frame === null)
            return Qt.rect(0, 0, 0, 0)
        const m = frame.area
        const push = gap - closest * shrink
        const pushX = (frame.width - m.width * shrink) / 2 + push
        const pushY = (frame.height - m.height * shrink) / 2 + push
        let x = frame.x + frame.width / 2 + (area.x - (m.x + m.width / 2)) * shrink
        let y = frame.y + frame.height / 2 + (area.y - (m.y + m.height / 2)) * shrink
        if (area.x >= m.x + m.width) x += pushX
        else if (area.x + area.width <= m.x) x -= pushX
        if (area.y >= m.y + m.height) y += pushY
        else if (area.y + area.height <= m.y) y -= pushY
        return Qt.rect(x, y, area.width * shrink, area.height * shrink)
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
