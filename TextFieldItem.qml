import QtQuick
import QtQuick.Controls

// A text field to type in. Works inside a component or anywhere else.
TextArea {
    wrapMode: TextEdit.Wrap
    clip: true
    placeholderText: "Type here…"
}
