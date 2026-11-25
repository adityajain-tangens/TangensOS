import QtQuick
import QtQuick.Controls

// A chat with the AI: what was asked and answered, which can't be edited, and a line under it to ask the next thing.
// Questions are bold, on the right, and answers are on the left. Enter sends, Shift+Enter starts a new line.
// Works inside a component or anywhere else.
Item {
    id: chat

    // The first thing to ask. ComponentFrame fills it in.
    property string text
    onTextChanged: send(text)

    // Adds the question to the chat and asks the AI, with the whole chat so it knows what came before.
    // True if it was sent: not while the AI is still answering.
    function send(question) {
        question = question.trim()
        if (question === "" || ai.busy)
            return false
        TextFormatter.addMessage(history.textDocument, question, true)
        ai.ask(history.getText(0, history.length))
        return true
    }

    // Sends what's typed in the line, and empties it
    function sendTyped() {
        if (send(input.text))
            input.text = ""
    }

    AIClient {
        id: ai
        onReplyReady: (answer) => TextFormatter.addMessage(history.textDocument, answer, false)
        onFailed: (error) => TextFormatter.addMessage(history.textDocument, error, false)
    }

    // What was asked and answered
    ScrollView {
        anchors.fill: parent
        anchors.bottomMargin: input.height + 8

        TextArea {
            id: history
            readOnly: true
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.Wrap
            // Keep the newest message in view
            onLengthChanged: cursorPosition = length
        }
    }

    // The line to ask the next thing
    TextArea {
        id: input
        anchors.left: parent.left
        anchors.right: sendButton.left
        anchors.bottom: parent.bottom
        wrapMode: TextEdit.Wrap
        placeholderText: "Ask a follow-up…"
        Keys.onReturnPressed: (event) => {
            if (event.modifiers & Qt.ShiftModifier)
                event.accepted = false
            else
                chat.sendTyped()
        }
    }

    Button {
        id: sendButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: "↑"
        focusPolicy: Qt.NoFocus
        enabled: !ai.busy
        onClicked: chat.sendTyped()
    }
}
