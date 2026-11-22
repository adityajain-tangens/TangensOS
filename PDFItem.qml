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
    // How far it's scrolled, in PDF points rather than pixels, so it's the same at any width
    readonly property point scroll: pages === null ? Qt.point(0, 0)
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
        const to = pendingScroll
        pendingScroll = null
        Qt.callLater(() => {
            pages.contentX = to.x * renderScale
            pages.contentY = to.y * renderScale
        })
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
