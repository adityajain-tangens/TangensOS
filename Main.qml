import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// the floating AI bar
Window {
    id: bar
    width: 640
    height: 56
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    title: "OSDemo"

    // the workspace window the bar sits on, or null when centered
    property WorkspaceWindow attachedWindow: null
    property int openedCount: 0

    // centered on screen, or at the bottom of the attached window
    x: attachedWindow ? attachedWindow.x + (attachedWindow.width - width) / 2
                      : Screen.virtualX + (Screen.width - width) / 2
    y: attachedWindow ? attachedWindow.y + attachedWindow.height - height / 2
                      : Screen.virtualY + (Screen.height - height) / 2

    // new window when centered, follow-up when attached
    function send(prompt) {
        if (prompt.trim() === "")
            return
        if (attachedWindow)
            attachedWindow.ask(prompt)
        else
            openWorkspace(prompt)
        input.text = ""
    }

    // opens a workspace window, offset a little from the last one
    function openWorkspace(prompt) {
        const offset = (openedCount % 5) * 30
        const win = workspaceComponent.createObject(null, {
            title: prompt,
            x: Screen.virtualX + (Screen.width - 900) / 2 + offset,
            y: Screen.virtualY + 80 + offset
        })
        openedCount++
        win.focused.connect(() => attachedWindow = win)
        win.closed.connect(() => {
            if (attachedWindow === win)
                attachedWindow = null
        })
        attachedWindow = win
        win.ask(prompt)
    }

    Component {
        id: workspaceComponent
        WorkspaceWindow {}
    }

    SystemPalette { id: system }

    // the bar itself
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: system.window
        border.color: system.mid

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10

            TextField {
                id: input
                Layout.fillWidth: true
                placeholderText: attachedWindow ? "Ask about this window…" : "Ask anything…"
                font.pixelSize: 18
                background: null
                focus: true
                onAccepted: send(text)
                Keys.onEscapePressed: text = ""
            }

            // spinner while the attached window waits for the AI
            BusyIndicator {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                running: attachedWindow !== null && attachedWindow.busy
                visible: running
            }
        }
    }
}