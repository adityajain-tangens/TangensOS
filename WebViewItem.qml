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
    // the page's title, address and all the text that can be seen on it, and the image at that point, if there is one.
    // Leaves out menus, footers and sidebars, where promotions and link lists usually are, and hidden text.
    function askContext(point, done) {
        const at = page.mapFromItem(web, point)
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
            const image = document.elementFromPoint(${at.x}, ${at.y})?.closest("img")
            return {
                selected: getSelection().toString(),
                around: document.title + " (" + location.href + ")\\n\\n" + seen.join(" "),
                image: image ? image.currentSrc || image.src : ""
            }
        })()`, (found) => done(found ?? {}))
    }

    // Opens what was typed: a web address (like apple.com or chrome://gpu), or a Google search for anything else
    function go(typed) {
        const text = typed.trim()
        if (text === "")
            return
        if (text.includes("://") || text.includes(".") && !text.includes(" "))
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
        // Remembers cookies and logins between launches (WebProfile.qml)
        profile: WebProfile
        url: "https://www.google.com"

        // TEMPORARY: logs, with the time, each scroll event the page gets and each time it actually moves.
        // "blocking" means the page could have stopped the scroll itself, so Chromium had to wait for it.
        onLoadingChanged: if (!loading) runJavaScript(`(() => {
            if (window.__scrollLog) return
            window.__scrollLog = true
            const now = () => Date.now() % 100000
            addEventListener("wheel", (e) => console.log("[scroll] page wheel", now(),
                "sent", Math.round((performance.timeOrigin + e.timeStamp) % 100000), "dy", Math.round(e.deltaY),
                e.cancelable ? "blocking" : ""), { passive: true, capture: true })
            document.addEventListener("scroll", (e) => {
                const el = e.target === document ? document.scrollingElement : e.target
                console.log("[scroll] page moved", now(), "y", Math.round(el.scrollTop),
                    e.target === document ? "" : "(inner: " + el.tagName + "." + el.className + ")")
            }, { passive: true, capture: true })
        })()`)
        // TEMPORARY: shows those logs in Qt Creator's output
        onJavaScriptConsoleMessage: (level, message) => { if (message.startsWith("[scroll]")) console.log(message) }
    }

    // On top of the page, sees each trackpad scroll before the page does. All are passed on, except the
    // one macOS sends when its momentum ends (like when fingers rest on the trackpad to stop it). Qt WebEngine
    // hands it to the page as if the fingers were lifted while moving, so the page would keep sliding by
    // itself instead of stopping.
    MouseArea {
        anchors.fill: page
        // Only scrolling: clicks, hovering and right clicks go to the page
        acceptedButtons: Qt.NoButton
        // True while macOS's momentum is moving the page
        property bool inMomentum: false
        onWheel: (wheel) => {
            // TEMPORARY: logs every scroll event before the page gets it
            console.log("[scroll] qt  ", Date.now() % 100000, "phase", wheel.phase, "dy", wheel.pixelDelta.y)
            if (wheel.phase === Qt.ScrollMomentum)
                inMomentum = true
            else if (wheel.phase === Qt.ScrollBegin || wheel.phase === Qt.ScrollUpdate)
                inMomentum = false
            // Kept here, not passed on, when it ends the momentum
            wheel.accepted = wheel.phase === Qt.ScrollEnd && inMomentum
            // TEMPORARY TEST: also keep back the "fingers lifted" end, so the page never gets any end
            wheel.accepted = wheel.phase === Qt.ScrollEnd
            // TEMPORARY
            if (wheel.accepted)
                console.log("[scroll] swallowed")
        }
    }
}