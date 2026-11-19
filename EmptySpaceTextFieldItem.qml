import QtQuick
import QtQuick.Controls

// Text typed straight onto the workspace, where an empty spot was clicked.
// No background or border: only the placeholder, then the typed text.
// If it's left empty when you click away, it goes away.
TextArea {
    padding: 0
    background: null
    placeholderText: "Start typing..."
    onActiveFocusChanged: if (!activeFocus && text === "") destroy()
}
