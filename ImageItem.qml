import QtQuick

// Shows one image file, as large as fits without stretching it. Works inside a component or anywhere else.
Image {
    // The image file to show, like file:///Users/me/photo.png
    property url file

    source: file
    fillMode: Image.PreserveAspectFit
    // Load it at the size it's shown in real screen pixels (2 per point on a Retina screen),
    // so SVGs stay sharp and big photos don't use extra memory. Photos are never enlarged past their own size.
    sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
    asynchronous: true

    // What to ask the AI about when it's right-clicked (ComponentFrame): this image
    function askContext(point, done) {
        done({ image: file.toString() })
    }
}
