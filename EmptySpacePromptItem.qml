import QtQuick
import QtQuick.Controls

// What appears where an empty spot of the workspace was clicked: a text field to type in,
// with a menu of things to do right below it while it's being typed in.
// If the text field is left empty when you click away, it all goes away.
Column {
    id: prompt

    property alias textField: textField
    // Sent when "Search on the web" is clicked, with what's been typed so far
    signal searchWeb(string text)
    // Sent when "Add a note" is clicked, with what's been typed so far
    signal addNote(string text)
    // Sent when "Add an image/video" is clicked
    signal addDropZone()
    // Sent when "Ask AI" is clicked, with what's been typed so far
    signal askAI(string text)

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
            { icon: "📝", title: "Add a note" },
            { icon: "✨", title: "Ask AI" }
        ]
        onClicked: (index) => {
            if (index === 0)
                prompt.searchWeb(textField.text)
            else if (index === 1)
                prompt.addDropZone()
            else if (index === 2)
                prompt.addNote(textField.text)
            else if (index === 3)
                prompt.askAI(textField.text)
        }
    }
}
