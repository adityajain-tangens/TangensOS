import QtQuick
import QtQuick.Controls

// The app's only window. It always fills the whole screen.
ApplicationWindow {
    width: Screen.width
    height: Screen.height
    visible: true
    visibility: Window.FullScreen
    title: "Tangens"

    // The components on the workspace and where they sit on it (WorkspaceModel.cpp)
    WorkspaceModel {
        id: componentList
    }

    Workspace {
        id: workspace
        anchors.fill: parent
        components: componentList
        onComponentClicked: (frame) => maximizedView.show(frame)
    }

    // The UI on top of the workspace, which doesn't scroll or zoom with it (OverlayView.qml)
    OverlayView {
        anchors.fill: parent
        workspace: workspace
    }

    // A clicked component, shown big and usable, in front of everything else (MaximizedViewItem.qml)
    MaximizedViewItem {
        id: maximizedView
        anchors.fill: parent
        workspace: workspace
    }
}
