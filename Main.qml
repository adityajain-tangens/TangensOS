import QtQuick
import QtQuick.Controls

// The app's only window. It always fills the whole screen.
ApplicationWindow {
    width: Screen.width
    height: Screen.height
    visible: true
    visibility: Window.FullScreen
    title: "Tangens"

    // The components on the workspace and where they sit on the grid (WorkspaceModel.cpp)
    WorkspaceModel {
        id: componentList
    }

    Workspace {
        id: workspace
        anchors.fill: parent
        components: componentList
    }

    // Cmd+G (Ctrl+G on Windows) shows or hides the grid, to check the layout by eye
    Shortcut {
        sequence: "Ctrl+G"
        onActivated: workspace.showGrid = !workspace.showGrid
    }
}
