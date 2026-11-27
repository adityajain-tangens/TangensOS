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
        // Gets no clicks, drags, pinches or wheel turns while a component is maximized
        enabled: maximizedView.frames.length === 0
        onComponentClicked: (frame) => maximizedView.show(frame)
        onAskAbout: (context, scenePosition) => askPopup.ask(context, scenePosition)
    }

    // The UI on top of the workspace, which doesn't scroll or zoom with it (OverlayView.qml)
    OverlayView {
        anchors.fill: parent
        workspace: workspace
        enabled: maximizedView.frames.length === 0
    }

    // A clicked component, shown big and usable, in front of the workspace and OverlayView (MaximizedViewItem.qml)
    MaximizedViewItem {
        id: maximizedView
        anchors.fill: parent
        workspace: workspace
    }

    // Undo and redo, in front of everything, even the maximized components (TopMostViewItem.qml)
    TopMostViewItem {
        anchors.fill: parent
    }

    // Cmd+T while a web page is maximized, like a new tab: a new web page next to it on the workspace, shown maximized too.
    // With several maximized, next to the first.
    Shortcut {
        sequence: StandardKey.AddTab
        enabled: maximizedView.frames.some(f => f.item === "WebViewItem")
        onActivated: maximizedView.show(workspace.addBeside(maximizedView.frames.find(f => f.item === "WebViewItem"), "WebViewItem"))
    }

    // A card to ask the AI about something right-clicked, in front of everything (AskPopupItem.qml)
    AskPopupItem {
        id: askPopup
    }
}
