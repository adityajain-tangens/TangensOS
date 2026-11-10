import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// a window that holds one workspace, built up from parts
ApplicationWindow {
    id: workspace
    width: 900
    height: 650
    visible: true
    opacity: 0

    property string message: ""
    property string lastPrompt: ""
    // last few requests and what the AI did
    property var history: []
    readonly property bool busy: ai.busy

    signal focused()
    signal closed()

    // one row per part: partId, title, content (JSON text)
    ListModel { id: parts }

    // sends a request with the current parts and recent history
    function ask(prompt) {
        if (ai.busy)
            return
        message = "Thinking…"
        lastPrompt = prompt
        ai.ask("Current parts:\n" + partsJson()
               + "\n\nRecent history:\n" + (history.length ? history.join("\n") : "none")
               + "\n\nRequest: " + prompt)
    }

    // the parts as plain JSON for the AI
    function partsJson() {
        const list = []
        for (let i = 0; i < parts.count; i++) {
            const part = parts.get(i)
            list.push({ id: part.partId, title: part.title, content: JSON.parse(part.content) })
        }
        return JSON.stringify(list)
    }

    function indexOfPart(id) {
        for (let i = 0; i < parts.count; i++) {
            if (parts.get(i).partId === id)
                return i
        }
        return -1
    }

    // applies the AI's edits, skipping any that don't make sense
    function applyReply(json) {
        let reply
        try {
            reply = JSON.parse(json)
        } catch (error) {
            message = "Couldn't read the reply:\n" + json
            return
        }
        for (const op of reply.ops ?? [])
            applyOp(op)

        const note = reply.say ?? ""
        const intent = Array.isArray(reply.intent) ? "   ·   intent: " + reply.intent.join(", ") : ""
        message = note + intent
        history = history.concat("User: " + lastPrompt + " -> AI: " + note).slice(-6)
    }

    function applyOp(op) {
        if (op.op === "add" && op.part && op.part.id) {
            const row = {
                partId: op.part.id,
                title: op.part.title ?? "",
                content: JSON.stringify(op.part.content ?? {})
            }
            const existing = indexOfPart(op.part.id)
            const after = indexOfPart(op.after)
            // adding an id that exists just replaces it
            if (existing >= 0)
                parts.set(existing, row)
            else if (after >= 0)
                parts.insert(after + 1, row)
            else
                parts.append(row)
        } else if (op.op === "replace") {
            const index = indexOfPart(op.id)
            if (index < 0)
                return
            if (op.title)
                parts.setProperty(index, "title", op.title)
            if (op.content)
                parts.setProperty(index, "content", JSON.stringify(op.content))
        } else if (op.op === "remove") {
            const index = indexOfPart(op.id)
            if (index >= 0)
                parts.remove(index)
        }
    }

    // runs when a generated button is clicked
    function handleAction(action) {
        if (action.type === "open_url")
            Qt.openUrlExternally(action.url)
        else if (action.type === "ask")
            ask(action.prompt)
    }

    onActiveChanged: if (active) focused()
    onClosing: {
        closed()
        destroy()
    }

    AIClient {
        id: ai
        onReplyReady: (json) => applyReply(json)
        onFailed: (error) => message = "Error: " + error
    }

    // fade and grow in when opened
    Component.onCompleted: openAnimation.start()
    ParallelAnimation {
        id: openAnimation
        NumberAnimation { target: workspace; property: "opacity"; to: 1; duration: 250 }
        NumberAnimation { target: content; property: "scale"; from: 0.96; to: 1; duration: 300; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        // room for the bar at the bottom
        anchors.bottomMargin: 44
        spacing: 12

        // "Thinking…", the AI's note, or errors
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: ai.busy ? ai.status : message
            wrapMode: Text.Wrap
            opacity: 0.6
        }

        ScrollView {
            id: resultsView
            Layout.fillWidth: true
            Layout.fillHeight: true

            // the parts, stacked
            ColumnLayout {
                width: resultsView.availableWidth
                spacing: 24

                Repeater {
                    model: parts
                    delegate: ColumnLayout {
                        id: partView
                        required property string title
                        required property string content
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: partView.title
                            visible: partView.title !== ""
                            font.pixelSize: 13
                            font.bold: true
                            opacity: 0.6
                        }

                        NodeView {
                            Layout.fillWidth: true
                            node: JSON.parse(partView.content)
                            onActionTriggered: (action) => handleAction(action)
                        }
                    }
                }
            }
        }
    }
}