import QtQuick

// The UI that sits on top of the workspace, not in it: it fills the window and stays put
// while the workspace scrolls and zooms. Put toolbars, buttons, indicators and the like in here,
// placed with anchors against the window's edges.
// Where it has nothing, clicks, drags, pinches and the wheel go through to the workspace underneath.
Item {
    id: overlay

    // The workspace underneath, for subviews that read or change it, like workspace.zoom
    required property Workspace workspace
}
