import QtQuick
import QtQuick.Pdf

// Shows a PDF file, each page under the one before. Scroll to move through it.
// Works inside a component or anywhere else.
PdfMultiPageView {
    id: view

    // The PDF file to show, like file:///Users/me/report.pdf
    property url file

    clip: true
    document: PdfDocument {
        source: view.file
        // Fit the pages to the width once the file has loaded
        onStatusChanged: view.fitToWidth()
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
