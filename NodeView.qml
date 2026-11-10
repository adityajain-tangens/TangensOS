import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// draws one UI node from JSON, then its children
Loader {
    id: root
    property var node: ({})
    signal actionTriggered(var action)

    // loads a child by file name (workaround, see notes)
    function loadChild(loader, childNode) {
        loader.setSource("NodeView.qml", { node: childNode })
        loader.item.actionTriggered.connect(root.actionTriggered)
    }

    // pick the component for this node's type
    sourceComponent: {
        switch (node.type) {
        case "Column": return columnView
        case "Row": return rowView
        case "Card": return cardView
        case "Text": return textView
        case "Button": return buttonView
        case "Image": return imageView
        default: return unknownView
        }
    }

    Component {
        id: columnView
        ColumnLayout {
            spacing: 10
            Repeater {
                model: root.node.children ?? []
                delegate: Loader {
                    Layout.fillWidth: modelData.type !== "Button"
                    Component.onCompleted: root.loadChild(this, modelData)
                }
            }
        }
    }

    Component {
        id: rowView
        RowLayout {
            spacing: 10
            Repeater {
                model: root.node.children ?? []
                delegate: Loader {
                    // equal widths for each child
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    Component.onCompleted: root.loadChild(this, modelData)
                }
            }
        }
    }

    Component {
        id: cardView
        Frame {
            padding: 14
            ColumnLayout {
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.node.children ?? []
                    delegate: Loader {
                        Layout.fillWidth: modelData.type !== "Button"
                        Component.onCompleted: root.loadChild(this, modelData)
                    }
                }
            }
        }
    }

    Component {
        id: textView
        Label {
            text: root.node.text ?? ""
            wrapMode: Text.Wrap
            font.pixelSize: root.node.style === "title" ? 22 : root.node.style === "caption" ? 12 : 15
            font.bold: root.node.style === "title"
            opacity: root.node.style === "caption" ? 0.7 : 1
        }
    }

    Component {
        id: buttonView
        Button {
            text: root.node.label ?? "Button"
            onClicked: root.actionTriggered(root.node.action ?? {})
        }
    }

    Component {
        id: imageView
        Image {
            source: root.node.url ?? ""
            sourceSize.height: 160
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
    }

    // shown for types we don't support
    Component {
        id: unknownView
        Label {
            text: "Unsupported: " + (root.node.type ?? "?")
            opacity: 0.5
        }
    }
}