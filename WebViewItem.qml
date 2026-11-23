import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

// A web page with back, forward and reload buttons and an address field.
// Works inside a component or anywhere else.
Item {
    id: web

    // What to open first, opened like what's typed in the address field. ComponentFrame fills it in.
    property string text
    onTextChanged: go(text)

    // What to ask the AI about when it's right-clicked (ComponentFrame): the text selected on the page, if any,
    // and the page's title, address and all the text that can be seen on it.
    // Leaves out menus, footers and sidebars, where promotions and link lists usually are, and hidden text.
    function askText(done) {
        page.runJavaScript(`(() => {
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT)
            const range = document.createRange()
            const seen = []
            for (let node; (node = walker.nextNode());) {
                if (node.textContent.trim() === "" || node.parentElement.closest("nav, footer, aside, script, style, noscript"))
                    continue
                range.selectNodeContents(node)
                const r = range.getBoundingClientRect()
                if (r.width > 0 && r.bottom > 0 && r.top < innerHeight && r.right > 0 && r.left < innerWidth)
                    seen.push(node.textContent.trim())
            }
            return [getSelection().toString(), document.title + " (" + location.href + ")\\n\\n" + seen.join(" ")]
        })()`, (found) => done(found[0], found[1]))
    }

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