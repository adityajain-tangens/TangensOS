import QtQuick

// A live, scaled-down picture of a component on the workspace, so a playing video keeps moving.
// It's only shown: it can't be clicked or used.
ShaderEffectSource {
    // The component on the workspace it shows
    required property ComponentFrame component

    sourceItem: component
    // Smooth when drawn much smaller than the component
    mipmap: true
}
