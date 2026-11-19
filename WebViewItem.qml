import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

// A web page with back, forward and reload buttons and an address field.
// Works inside a component or anywhere else.
Item {
    id: web

    // Opens what was typed: a web address, or a Google search for anything else
    function go(typed) {
        const text = typed.trim()
        if (text === "")
            return
        if (text.includes(".") && !text.includes(" "))
            page.url = text.includes("://") ? text : "https://" + text
        else
            page.url = "https://www.google.com/search?q=" + encodeURIComponent(text)
    }

    // The bar across the top
    RowLayout {
        id: bar
        width: parent.width
        spacing: 2

        ToolButton {
            text: "‹"
            enabled: page.canGoBack
            onClicked: page.goBack()
        }
        ToolButton {
            text: "›"
            enabled: page.canGoForward
            onClicked: page.goForward()
        }
        ToolButton {
            text: "↻"
            onClicked: page.reload()
        }
        TextField {
            Layout.fillWidth: true
            text: page.url
            selectByMouse: true
            onAccepted: web.go(text)
        }
    }

    // The page itself, filling the space below the bar
    WebEngineView {
        id: page
        anchors.top: bar.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        url: "https://www.google.com"
    }
}