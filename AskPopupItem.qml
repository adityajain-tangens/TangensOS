import QtQuick
import QtQuick.Controls

// A small card to ask the AI about something that was right-clicked, like selected text or an image.
// First a line to type the question in, then the question and the AI's answer under it.
// Clicking outside it, or Esc, closes it.
Popup {
    id: popup

    // What's being asked about: the selected text, the text around it and an image, each only if there is one
    property var context: ({})
    property string question
    property string answer

    width: 360
    padding: 12
    focus: true

    // Opens at this point in the window, to ask about this
    function ask(found, at) {
        context = found
        question = ""
        answer = ""
        input.text = ""
        x = Math.min(at.x, parent.width - width - 8)
        y = Math.min(at.y, parent.height - 200)
        open()
        input.forceActiveFocus()
    }

    function send() {
        if (input.text.trim() === "")
            return
        question = input.text.trim()
        const selected = context.selected ?? "", around = context.around ?? ""
        let text = "Question: " + question
        if (around !== "")
            text = (selected !== "" ? "The selected part:\n" + selected + "\n\nThe text around it:\n" : "The text:\n") + around + "\n\n" + text
        ai.ask(text, context.image ?? "")
    }

    AIClient {
        id: ai
        onReplyReady: (text) => popup.answer = text
        onFailed: (error) => popup.answer = error
    }

    background: Rectangle {
        radius: 12
        color: "white"
        border.color: "#dddad3"
    }

    contentItem: Column {
        spacing: 8

        // Before it's sent: the line to type the question in, and the send button. Enter sends too.
        Row {
            visible: popup.question === ""
            spacing: 8

            TextField {
                id: input
                width: popup.availableWidth - sendButton.width - 8
                placeholderText: popup.context.image ? "Ask about this image…" : "Ask about this…"
                onAccepted: popup.send()
            }
            Button {
                id: sendButton
                text: "↑"
                focusPolicy: Qt.NoFocus
                onClicked: popup.send()
            }
        }

        // After: the question, then the answer
        Text {
            visible: popup.question !== ""
            width: popup.availableWidth
            text: "✨ " + popup.question
            font.bold: true
            wrapMode: Text.Wrap
        }
        Text {
            visible: popup.question !== ""
            width: popup.availableWidth
            text: ai.busy ? "…" : popup.answer
            color: "#333"
            wrapMode: Text.Wrap
        }
    }
}
