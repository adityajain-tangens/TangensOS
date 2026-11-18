import QtQuick
import QtQuick.Controls

// A text field to type in, with a formatting bar on top. Works inside a component or anywhere else.
Item {
    id: textField

    // A button on the bar. It never takes focus, so the text keeps its selection.
    component FormatButton: ToolButton {
        focusPolicy: Qt.NoFocus
        implicitWidth: 32
        implicitHeight: 28
    }

    // The bar
    Row {
        id: bar
        spacing: 2

        // The font, from the ones installed on this computer. Shows the selected text's font.
        ComboBox {
            width: 150
            height: 28
            focusPolicy: Qt.NoFocus
            model: Qt.fontFamilies()
            displayText: area.cursorSelection.font.family
            onActivated: (index) => {
                area.cursorSelection.font.family = model[index]
                area.forceActiveFocus()
            }
        }

        // The size, in points. Shows the selected text's size.
        ComboBox {
            width: 64
            height: 28
            focusPolicy: Qt.NoFocus
            model: [8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 36, 48, 72]
            displayText: Math.round(area.cursorSelection.font.pointSize)
            onActivated: (index) => {
                area.cursorSelection.font.pointSize = model[index]
                area.forceActiveFocus()
            }
        }

        // Bold, italics and underline: lit up when the selected text already has them
        FormatButton {
            text: "B"
            font.bold: true
            checkable: true
            checked: area.cursorSelection.font.bold
            onClicked: area.cursorSelection.font.bold = checked
        }
        FormatButton {
            text: "I"
            font.italic: true
            checkable: true
            checked: area.cursorSelection.font.italic
            onClicked: area.cursorSelection.font.italic = checked
        }
        FormatButton {
            text: "U"
            font.underline: true
            checkable: true
            checked: area.cursorSelection.font.underline
            onClicked: area.cursorSelection.font.underline = checked
        }

        // These change whole lines, and undo themselves when pressed again (TextFormatter.cpp)
        FormatButton {
            text: "H"
            font.bold: true
            onClicked: TextFormatter.toggleHeadline(area.textDocument, area.selectionStart, area.selectionEnd)
        }
        FormatButton {
            text: "•"
            onClicked: TextFormatter.toggleBullets(area.textDocument, area.selectionStart, area.selectionEnd)
        }
        FormatButton {
            text: "1."
            onClicked: TextFormatter.toggleNumbers(area.textDocument, area.selectionStart, area.selectionEnd)
        }
        FormatButton {
            text: "☐"
            onClicked: TextFormatter.toggleCheckboxes(area.textDocument, area.selectionStart, area.selectionEnd)
        }
    }

    // Where the text goes
    TextArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: bar.height + 4
        textFormat: TextEdit.RichText
        // Keep the selection while a font list is open, so the choice applies to it
        persistentSelection: true
        wrapMode: TextEdit.Wrap
        clip: true
        placeholderText: "Type here…"

        // A click to the left of a line, where its checkbox is, ticks or unticks it
        onReleased: (event) => {
            const position = positionAt(event.x, event.y)
            if (event.x < positionToRectangle(position).x - 4)
                TextFormatter.flipCheckbox(textDocument, position)
        }
    }
}
