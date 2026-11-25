import QtQuick

// The frame every component sits in. Drag it from anywhere to move it, or a corner to resize it.
// What sits inside is a ComponentItem, named in the model (see WorkspaceModel.cpp). It's only shown:
// it's turned off, so clicks, typing and the scroll wheel never reach it, and a web page can't be used.
// Clicking it sends clicked(), and MaximizedViewItem shows it maximized, where it can be used.
Rectangle {
    id: frame

    // Filled in from this component's entry in the model
    required property int index
    // Its place on the workspace, at full size
    required property rect area
    required property string item
    required property string file
    required property string text
    // How far what's inside is scrolled, for items that scroll (like WebViewItem): a point, or undefined.
    // For a GridItem, a point for each of its files that has one, by the file's URL.
    required property var scroll

    // True while it's shown big in MaximizedViewItem: what's inside can be used,
    // and it can't be dragged or deleted
    property bool maximized: false

    // True while it's being dragged
    readonly property bool dragging: grab.active
    // True while it's being moved by its top bar while maximized
    readonly property bool moving: barGrab.active
    // Where the pointer is in the window while it's dragged
    readonly property point dragPoint: grab.centroid.scenePosition

    // Sent while a corner is dragged: which corner, and how far the pointer has moved on screen since it was pressed
    signal resizeStarted()
    signal resizeMoved(bool atLeft, bool atTop, point moved)
    // Sent when the X button at the top is clicked
    signal closeClicked()
    // Sent when it's clicked anywhere else, without dragging
    signal clicked()
    // Sent when a file is dragged out of the item inside and let go, like from a GridItem
    signal fileDraggedOut(string file, point scenePosition)
    // Sent when the item inside wants another shape, like AppSnapshotItem for its picture: the shape
    // (width divided by height) of what's inside, not of the whole frame
    signal reshapeWanted(real aspect)
    // Sent when the item inside wants to be at a certain place on screen, like AppSnapshotItem over its
    // app's window: where the whole frame should be for it, in its parent's coordinates
    signal areaWanted(rect area)
    // Sent when the item inside changes its text (like typing in a TextFieldItem, or a WebViewItem going
    // to another page), or is scrolled, so the workspace can save it
    signal textEdited(string text)
    signal scrolled(var scroll)

    // The frame's area that puts what's inside at `area`, in screen points
    function areaFor(area) {
        const topLeft = parent.mapFromGlobal(area.x, area.y)
        areaWanted(Qt.rect(topLeft.x - content.anchors.leftMargin, topLeft.y - content.anchors.topMargin,
                           area.width + content.anchors.leftMargin + content.anchors.rightMargin,
                           area.height + content.anchors.topMargin + content.anchors.bottomMargin))
    }

    // How much wider and taller the frame is than what's inside: its top bar and margins
    readonly property size chrome: Qt.size(content.anchors.leftMargin + content.anchors.rightMargin,
                                           content.anchors.topMargin + content.anchors.bottomMargin)
    // The shape (width divided by height) of what's inside. Shapes are kept by this, not by the whole
    // frame's: the top bar takes a bigger share of a small frame than of a big one.
    readonly property real contentAspect: (width - chrome.width) / (height - chrome.height)

    // Sent when it's right-clicked to ask the AI about what's inside, with where it was clicked in the window.
    // context has the selected text, the text around it and an image, each only if there is one.
    signal askAbout(var context, point scenePosition)

    radius: 12
    color: "white"
    border.color: "#dddad3"
    // In front of the others while it, or something in it, is dragged
    z: dragging || (content.item?.dragging ?? false) ? 1 : 0

    // When the model moves it, like when it's pushed aside, glide there instead of jumping.
    // A maximized one is moved by MaximizedViewItem's own animations instead.
    Behavior on x { enabled: !frame.maximized; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !frame.maximized; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on width { enabled: !frame.maximized; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: !frame.maximized; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    onDraggingChanged: if (dragging) forceActiveFocus()

    // Hold anywhere on the frame to drag it. Behind what's inside, so in a GridItem a press on a file drags the file.
    Item {
        anchors.fill: parent

        DragHandler {
            id: grab
            enabled: !frame.maximized
            target: frame
        }

        // Taking the focus closes an empty "Start typing..." field (EmptySpacePromptItem).
        // The X button's own tap reaches here too, so that one isn't a click.
        TapHandler {
            enabled: !frame.maximized
            onTapped: {
                frame.forceActiveFocus()
                if (!closeHover.hovered)
                    frame.clicked()
            }
        }
    }

    // While maximized, its top bar moves it around the window, kept inside it. Only here, not on the
    // workspace's model: it doesn't change where it goes back to.
    Item {
        width: parent.width
        height: 36

        DragHandler {
            id: barGrab
            enabled: frame.maximized
            target: frame
            xAxis.minimum: 0
            xAxis.maximum: frame.parent.width - frame.width
            yAxis.minimum: 0
            yAxis.maximum: frame.parent.height - frame.height
        }
    }

    // What's inside: loads the file the model names, like TextFieldItem.qml
    Loader {
        id: content
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 36
        source: frame.item === "" ? "" : frame.item + ".qml"
        // Turned off, so it gets no clicks, typing, hovering or scrolling: a web page can't be used.
        // Items whose files can be dragged out, like GridItem, stay on so their files can be dragged.
        // They turn off everything else in them themselves.
        // When maximized, it's on and can be used.
        enabled: frame.maximized || item !== null && "draggedOut" in item
        // Items that show a file, like ImageItem, follow this component's file. It's a binding, not a
        // one-time copy, because when a DropZoneItem is swapped for one (WorkspaceModel::replaceItem),
        // the new item loads before the file arrives.
        // Items that hold text, like TextFieldItem, start with this component's text, and say when it changes.
        // Items that scroll start scrolled to where they were, and say when they're scrolled.
        // A GridItem follows the positions of all its files, and says when one changes.
        // A GridItem's positions come before its files, which are shown as soon as it has them.
        onLoaded: {
            if ("scrolls" in item) {
                item.scrolls = Qt.binding(() => frame.scroll ?? {})
                item.scrollsEdited.connect(frame.scrolled)
            }
            if ("file" in item) item.file = Qt.binding(() => frame.file)
            if ("text" in item) {
                item.text = frame.text
                item.textChanged.connect(() => frame.textEdited(item.text))
            }
            if ("scroll" in item) {
                if (frame.scroll !== undefined)
                    item.scrollTo(frame.scroll)
                item.scrollChanged.connect(() => frame.scrolled(item.scroll))
            }
            if ("draggedOut" in item) item.draggedOut.connect(frame.fileDraggedOut)
            if ("shaped" in item) item.shaped.connect(frame.reshapeWanted)
            if ("screenAreaWanted" in item) item.screenAreaWanted.connect(frame.areaFor)
            if ("interactive" in item) item.interactive = Qt.binding(() => frame.maximized)
        }
    }

    // When it has nothing inside, a different pale colour per component, so they're easy to tell apart
    Rectangle {
        visible: frame.item === ""
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 36
        radius: 8
        color: Qt.hsla((frame.index * 0.17) % 1, 0.5, 0.85, 1)
    }

    // A right click asks the AI about what's inside. Items that have something to ask about give it with
    // askContext(), like TextFieldItem, for the spot that was clicked in them.
    // In front of what's inside, so a note or web page doesn't open its own menu instead.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        // TEMPORARY: logs every scroll event, then passes it on untouched
        onWheel: (wheel) => {
            console.log("wheel phase:", wheel.phase, "pixelDelta:", wheel.pixelDelta.y, "angleDelta:", wheel.angleDelta.y)
            wheel.accepted = false
        }
        onPressed: (mouse) => {
            const scenePosition = mapToItem(null, mouse.x, mouse.y)
            if (content.item !== null && "askContext" in content.item)
                content.item.askContext(content.item.mapFromItem(frame, mouse.x, mouse.y), (found) => {
                    if (found.around || found.image)
                        frame.askAbout(found, scenePosition)
                })
        }
    }

    // Its place on the workspace, to check the layout
    Text {
        x: 12
        y: 10
        text: frame.area.x + ", " + frame.area.y + "  ·  " + frame.area.width + " × " + frame.area.height
        color: "#555"
        font.pixelSize: 13
    }

    // The X button at the top right: deletes this component
    Text {
        visible: !frame.maximized
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 18 - height / 2
        text: "✕"
        color: closeHover.hovered ? "#222" : "#888"
        font.pixelSize: 14

        HoverHandler {
            id: closeHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: frame.closeClicked()
        }
    }

    // The four corners: invisible squares, centred on each corner, above everything else
    Repeater {
        model: 4
        Item {
            id: corner
            required property int index
            // 0 is top left, 1 top right, 2 bottom left, 3 bottom right
            readonly property bool atLeft: index % 2 === 0
            readonly property bool atTop: index < 2

            width: 16
            height: 16
            x: atLeft ? -width / 2 : frame.width - width / 2
            y: atTop ? -height / 2 : frame.height - height / 2

            // The diagonal resize arrow while the pointer is over it
            HoverHandler {
                cursorShape: corner.atLeft === corner.atTop ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
            }

            DragHandler {
                target: null
                onActiveChanged: if (active) frame.resizeStarted()
                onCentroidChanged: if (active) frame.resizeMoved(corner.atLeft, corner.atTop,
                    Qt.point(centroid.scenePosition.x - centroid.scenePressPosition.x, centroid.scenePosition.y - centroid.scenePressPosition.y))
            }
        }
    }
}