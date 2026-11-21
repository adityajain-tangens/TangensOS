#include "AIClient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>

static const char *serverUrl = "https://api.groq.com/openai/v1/chat/completions";
static const char *modelName = "openai/gpt-oss-120b";
static const char *systemPrompt = "You answer questions asked in a note. You get the whole note: its last question is the new one, "
                                  "and what comes before is what was asked and answered so far. "
                                  "Search the web when it needs current facts. Answer briefly, in plain text with no markdown.";

void AIClient::ask(const QString &prompt)
{
    const QByteArray key = qgetenv("GROQ_API_KEY");
    if (key.isEmpty()) {
        emit failed("GROQ_API_KEY is not set");
        return;
    }

    QNetworkRequest request { QUrl(serverUrl) };
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", "Bearer " + key);
    const QJsonObject body {
        { "model", modelName },
        { "reasoning_effort", "low" },
        { "tools", QJsonArray { QJsonObject { { "type", "browser_search" } } } },
        { "messages", QJsonArray {
            QJsonObject { { "role", "system" }, { "content", systemPrompt } },
            QJsonObject { { "role", "user" }, { "content", prompt } }
        } }
    };

    m_busy = true;
    emit busyChanged();
    QNetworkReply *reply = m_network.post(request, QJsonDocument(body).toJson());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_busy = false;
        emit busyChanged();
        const QJsonObject answer = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError) {
            const QString error = answer["error"]["message"].toString();
            emit failed(error.isEmpty() ? reply->errorString() : error);
            return;
        }
        emit replyReady(answer["choices"][0]["message"]["content"].toString());
    });
}
