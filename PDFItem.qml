import QtQuick
import QtQuick.Pdf

// Shows a PDF file, each page under the one before. Scroll to move through it.
// Works inside a component or anywhere else.
PdfMultiPageView {
    id: view

    // The PDF file to show, like file:///Users/me/report.pdf
    property url file

    // The view's own scrolling table of pages, inside it
    readonly property TableView pages: children.find(child => (child as TableView) !== null) ?? null
    // How far it's scrolled, in PDF points rather than pixels, so it's the same at any width.
    // Until it has been scrolled back to where it was, that's where it was, so the saved spot isn't lost.
    readonly property point scroll: pendingScroll !== null ? pendingScroll
                                  : pages === null ? Qt.point(0, 0)
                                  : Qt.point(pages.contentX / renderScale, pages.contentY / renderScale)
    // Where to scroll to once the file has loaded, or null
    property var pendingScroll: null
    function scrollTo(point) {
        pendingScroll = point
        applyScroll()
    }
    // Scrolls to pendingScroll, once the file has loaded: it may load before or after scrollTo() is called
    function applyScroll() {
        if (document.status !== PdfDocument.Ready || pendingScroll === null || pages === null)
            return
        rescroll.left = 5
        rescroll.start()
    }
    // Scrolls there several times over half a second, then stops. Once isn't enough: the pages are
    // still being laid out at their final size, which can move it back.
    Timer {
        id: rescroll
        property int left: 0
        interval: 100
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            view.pages.contentX = view.pendingScroll.x * view.renderScale
            view.pages.contentY = view.pendingScroll.y * view.renderScale
            if (--left > 0)
                return
            stop()
            view.pendingScroll = null
        }
    }

    clip: true
    document: PdfDocument {
        source: view.file
        // Fit the pages to the width once the file has loaded, then scroll to where it was
        onStatusChanged: {
            view.fitToWidth()
            view.applyScroll()
        }
    }

    // Also refit when the width changes
    onWidthChanged: fitToWidth()

    // Asks the document for the first page's size directly: the view's own scaleToWidth()
    // still has a placeholder size at the moment the file finishes loading
    function fitToWidth() {
        if (document.status === PdfDocument.Ready)
            // 20 leaves room for the scrollbar on the right
            renderScale = (width - 20) / document.pagePointSize(0).width
    }
}
