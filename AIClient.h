#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QtQml/qqmlregistration.h>

// Asks the AI (Groq) something and hands back its answer as plain text. It searches the web when it needs to.
// It can also be asked about an image: a file on this computer, or one on the web by its address.
// The key comes from the GROQ_API_KEY environment variable.
class AIClient : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // True while waiting for an answer
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    bool busy() const { return m_busy; }
    Q_INVOKABLE void ask(const QString &prompt, const QUrl &image = QUrl());

signals:
    void busyChanged();
    void replyReady(const QString &text);
    void failed(const QString &error);

private:
    QNetworkAccessManager m_network;
    bool m_busy = false;
};
