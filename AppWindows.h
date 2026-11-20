#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// The apps open on this Mac, and pictures of their windows (macOS only, see AppWindows.mm).
// Taking a picture needs the Screen Recording permission: macOS asks for it the first time.
class AppWindows : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit AppWindows(QObject *parent = nullptr);

    // The apps open right now, other than this one, each as { pid, name, icon }.
    // The icon is a PNG image, as a data: URL an Image can show.
    Q_INVOKABLE QVariantList openApps() const;

    // Takes a picture of the biggest window of the app with this pid. Sends captured() with it
    // as a data: URL, or failed() with why it couldn't.
    Q_INVOKABLE void capture(int pid);

signals:
    void captured(const QString &image);
    void failed(const QString &error);
};
