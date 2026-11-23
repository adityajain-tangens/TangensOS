cmake_minimum_required(VERSION 3.16)

project(Tangens VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia PdfQuick WebEngineQuick Network)

qt_standard_project_setup(REQUIRES 6.10)

qt_add_executable(appTangens
    main.cpp
)

# The QML files, bundled into the app under the name "Tangens"
qt_add_qml_module(appTangens
    URI Tangens
    QML_FILES
        Main.qml
        Workspace.qml
        ComponentFrame.qml
        TextFieldItem.qml
        AIChatItem.qml
        AskPopupItem.qml
        ImageItem.qml
        VideoItem.qml
        PDFItem.qml
        WebViewItem.qml
        EmptySpacePromptItem.qml
        ButtonsMenuItem.qml
        DropZoneItem.qml
        GridItem.qml
        OverlayView.qml
        MaximizedViewItem.qml
        MaximizedComponentsViewItem.qml
        ComponentSnapshotItem.qml
    SOURCES
        WorkspaceModel.h
        WorkspaceModel.cpp
        TextFormatter.h
        TextFormatter.cpp
        AIClient.h
        AIClient.cpp
)

set_target_properties(appTangens PROPERTIES
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appTangens
    PRIVATE Qt6::Quick Qt6::Multimedia Qt6::PdfQuick Qt6::WebEngineQuick Qt6::Network
)