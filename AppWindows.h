#pragma once

#include <QObject>
#include <QRect>
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

    // Moves and resizes the biggest window of the app with this pid to `rect`, in screen points,
    // and brings it to the front. Needs the Accessibility permission: the first time, macOS asks
    // for it and this does nothing. Returns whether it worked.
    Q_INVOKABLE bool placeWindow(int pid, const QRect &rect);

    // Where the biggest window of the app with this pid is, in screen points.
    // Empty without the Accessibility permission, or if it has no window.
    Q_INVOKABLE QRect windowRect(int pid) const;

signals:
    void captured(const QString &image);
    void failed(const QString &error);
};
