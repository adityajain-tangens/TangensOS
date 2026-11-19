import QtQuick
import QtQuick.Controls

// What appears where an empty spot of the workspace was clicked: a text field to type in,
// with a menu of things to do right below it while it's being typed in.
// If the text field is left empty when you click away, it all goes away.
Column {
    id: prompt

    property alias textField: textField

    spacing: 8

    // No background or border: only the placeholder, then the typed text
    TextArea {
        id: textField
        padding: 0
        background: null
        placeholderText: "Start typing..."
        onActiveFocusChanged: if (!activeFocus && text === "") prompt.destroy()
    }

    ButtonsMenuItem {
        visible: textField.activeFocus
        buttons: [
            { icon: "🔍", title: "Search on the web" },
            { icon: "🖼️", title: "Add an image/video" },
            { icon: "📝", title: "Add a note" }
        ]
    }
}
