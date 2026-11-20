pragma ComponentBehavior: Bound

import QtQuick

// The other components on the workspace, shown small around the maximized ones (ComponentSnapshotItem),
// laid out like on the workspace, around the smallest rectangle holding the maximized ones. Part of MaximizedViewItem.
// Tapping one sends tapped(), and MaximizedViewItem shows it maximized too.
// The biggest one fits in 300 × 300, and the others, and the distances between them, are shrunk by as much.
// They're hidden until the pointer comes within 100 pixels of the window's edges. Then they slide in from the
// side they're on while fading in. They stay while the pointer is over them or between them and the window's
// edge, and slide back out and fade away once it's farther in than that.
// Shown, the ones past each side of the maximized ones sit against that side of the window, 20 pixels in, keeping
// their distances from each other. Only when there are too many to fit beside it do they cover it, by up to 100 pixels.
Item {
    id: others

    required property Workspace workspace
    // The maximized components
    property list<ComponentFrame> frames
    // Sent when a thumbnail is tapped, with where it is
    signal tapped(ComponentFrame component, rect from)

    // The smallest rectangle holding all the maximized components: on the workspace, and as shown now
    readonly property rect maxArea: frames.reduce((all, f) => all.width === 0 ? f.area : unite(all, f.area), Qt.rect(0, 0, 0, 0))
    readonly property rect maxRect: frames.reduce((all, f) => all.width === 0 ? Qt.rect(f.x, f.y, f.width, f.height)
                                                                            : unite(all, Qt.rect(f.x, f.y, f.width, f.height)), Qt.rect(0, 0, 0, 0))
    function unite(a, b) {
        const left = Math.min(a.x, b.x), top = Math.min(a.y, b.y)
        return Qt.rect(left, top, Math.max(a.x + a.width, b.x + b.width) - left, Math.max(a.y + a.height, b.y + b.height) - top)
    }

    // True while they're shown. Hidden again each time a component is maximized or goes back.
    property bool open: false
    onFramesChanged: open = false
    // 1 when they're shown, 0 when hidden, and in between while sliding in or out
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // True while the pointer is within these distances of the window's edges
    function within(left, right, top, bottom) {
        const p = edgeHover.point.position
        return edgeHover.hovered && (p.x < left || p.x > width - right || p.y < top || p.y > height - bottom)
    }
    // Shown when the pointer comes within 100 pixels of the window's edges
    readonly property bool nearEdge: within(100, 100, 100, 100)
    onNearEdgeChanged: if (nearEdge) open = true
    // Hidden when it's farther in than that, and than the inner edges of the thumbnails on each side
    readonly property bool nearThumbnails: within(reach.left, reach.right, reach.top, reach.bottom)
    onNearThumbnailsChanged: if (!nearThumbnails) open = false

    // The components still on the workspace: every one but the maximized ones, which have left it
    readonly property var shown: frames.length === 0 ? [] : workspace.frames()

    // How much they're shrunk: the biggest one fits in 300 × 300
    readonly property real shrink: 300 / Math.max(...shown.map(f => Math.max(f.area.width, f.area.height)))

    // Where a component's thumbnail would be if not moved out to the window's sides: shrunk around the
    // maximized one's middle, like on the workspace
    function shrunk(area) {
        const m = maxArea
        return Qt.rect(maxRect.x + maxRect.width / 2 + (area.x - (m.x + m.width / 2)) * shrink,
                       maxRect.y + maxRect.height / 2 + (area.y - (m.y + m.height / 2)) * shrink,
                       area.width * shrink, area.height * shrink)
    }

    // Where a component counts as being on the workspace: where it is, or, when it's between the maximized
    // ones (inside the smallest rectangle holding them), just past the side of that rectangle its middle is nearest
    function outside(area) {
        const m = maxArea
        if (area.x >= m.x + m.width || area.x + area.width <= m.x || area.y >= m.y + m.height || area.y + area.height <= m.y)
            return area
        const middleX = area.x + area.width / 2, middleY = area.y + area.height / 2
        const toLeft = middleX - m.x, toRight = m.x + m.width - middleX
        const toTop = middleY - m.y, toBottom = m.y + m.height - middleY
        const nearest = Math.min(toLeft, toRight, toTop, toBottom)
        if (nearest === toLeft) return Qt.rect(m.x - area.width, area.y, area.width, area.height)
        if (nearest === toRight) return Qt.rect(m.x + m.width, area.y, area.width, area.height)
        if (nearest === toTop) return Qt.rect(area.x, m.y - area.height, area.width, area.height)
        return Qt.rect(area.x, m.y + m.height, area.width, area.height)
    }

    // The thumbnails past each side of the maximized ones, where shrunk() puts them
    readonly property var groups: {
        if (frames.length === 0)
            return { left: [], right: [], top: [], bottom: [] }
        const m = maxArea
        const past = (test) => shown.map(f => outside(f.area)).filter(test).map(shrunk)
        return {
            left: past(a => a.x + a.width <= m.x),
            right: past(a => a.x >= m.x + m.width),
            top: past(a => a.y + a.height <= m.y),
            bottom: past(a => a.y >= m.y + m.height)
        }
    }

    // How far the thumbnails past each side of the maximized one move out from where shrunk() puts them:
    // until the outermost is 20 pixels from the window's edge, or farther when there are too many to fit
    // beside the maximized one, so they cover at most 100 pixels of it
    readonly property var shifts: {
        const left = groups.left, right = groups.right, top = groups.top, bottom = groups.bottom
        const lefts = (rs) => rs.map(r => r.x), rights = (rs) => rs.map(r => r.x + r.width)
        const tops = (rs) => rs.map(r => r.y), bottoms = (rs) => rs.map(r => r.y + r.height)
        return {
            left: left.length === 0 ? 0 : Math.max(Math.min(...lefts(left)) - 20, Math.max(...rights(left)) - (maxRect.x + 100)),
            right: right.length === 0 ? 0 : Math.max(width - 20 - Math.max(...rights(right)), maxRect.x + maxRect.width - 100 - Math.min(...lefts(right))),
            top: top.length === 0 ? 0 : Math.max(Math.min(...tops(top)) - 20, Math.max(...bottoms(top)) - (maxRect.y + 100)),
            bottom: bottom.length === 0 ? 0 : Math.max(height - 20 - Math.max(...bottoms(bottom)), maxRect.y + maxRect.height - 100 - Math.min(...tops(bottom)))
        }
    }

    // How far in from each of the window's edges the thumbnails on that side reach once shown, and at least 100
    readonly property var reach: ({
        left: Math.max(100, ...groups.left.map(r => r.x + r.width - shifts.left)),
        right: Math.max(100, ...groups.right.map(r => width - (r.x + shifts.right))),
        top: Math.max(100, ...groups.top.map(r => r.y + r.height - shifts.top)),
        bottom: Math.max(100, ...groups.bottom.map(r => height - (r.y + shifts.bottom)))
    })

    // Where a component's thumbnail goes: moved out to the sides of the window it's past.
    // While hidden, 100 pixels farther out, where it slides in from.
    function placeOf(area) {
        // Just as the maximized one goes back, before the thumbnails are taken away
        if (frames.length === 0)
            return Qt.rect(0, 0, 0, 0)
        const m = maxArea
        area = outside(area)
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
            id: thumbnail
            required property ComponentFrame modelData
            component: modelData
            opacity: others.reveal
            readonly property rect place: others.placeOf(modelData.area)
            x: place.x
            y: place.y
            width: place.width
            height: place.height

            // Only while shown. Takes the press, so the click doesn't also land behind and hide the maximized ones.
            TapHandler {
                enabled: others.open
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: others.tapped(thumbnail.component, Qt.rect(thumbnail.x, thumbnail.y, thumbnail.width, thumbnail.height))
            }
        }
    }
}
