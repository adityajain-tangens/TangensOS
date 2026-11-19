#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

int main(int argc, char *argv[])
{
    // Web pages need their engine set up before anything else starts
    QtWebEngineQuick::initialize();
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    // If Main.qml has an error, quit instead of running with no window
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("Tangens", "Main");

    return QGuiApplication::exec();
}