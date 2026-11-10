#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QJsonObject>
#include <QtQml/qqmlregistration.h>
#include <functional>

// sends a prompt to the AI (Gemini, or Groq in two steps) and returns JSON
class AIClient : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit AIClient(QObject *parent = nullptr);

    bool busy() const { return !m_status.isEmpty(); }
    QString status() const { return m_status; }
    Q_INVOKABLE void ask(const QString &prompt);

signals:
    void busyChanged();
    void statusChanged();
    void replyReady(const QString &json);
    void failed(const QString &error);

private:
    void askGemini(const QString &prompt);
    void research(const QString &prompt, int retries);
    void build(const QString &prompt, const QString &notes);
    void post(const QNetworkRequest &request, const QJsonObject &body,
              const std::function<void(const QJsonObject &, const QString &)> &done);
    void setStatus(const QString &status);

    QNetworkAccessManager m_network;
    QString m_status;
};