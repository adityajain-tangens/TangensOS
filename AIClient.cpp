#include "AIClient.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QNetworkReply>

static const char *serverUrl = "https://api.groq.com/openai/v1/chat/completions";
static const char *modelName = "openai/gpt-oss-120b";
// The one that can see images. It can't search the web.
static const char *visionModel = "qwen/qwen3.8-27b";
static const char *systemPrompt = "Answer briefly, in plain text with no markdown. Search the web when it needs current facts.";

void AIClient::ask(const QString &prompt, const QUrl &image)
{
    const QByteArray key = qgetenv("GROQ_API_KEY");
    if (key.isEmpty()) {
        emit failed("GROQ_API_KEY is not set");
        return;
    }

    // With an image, the prompt goes with it. One on this computer is sent as data, one on the web by its address.
    QJsonValue content = prompt;
    if (!image.isEmpty()) {
        QString imageUrl = image.toString();
        if (image.isLocalFile()) {
            QFile file(image.toLocalFile());
            if (!file.open(QIODevice::ReadOnly)) {
                emit failed("Couldn't read the image");
                return;
            }
            imageUrl = "data:" + QMimeDatabase().mimeTypeForFile(file.fileName()).name() + ";base64," + file.readAll().toBase64();
        }
        content = QJsonArray {
            QJsonObject { { "type", "text" }, { "text", prompt } },
            QJsonObject { { "type", "image_url" }, { "image_url", QJsonObject { { "url", imageUrl } } } }
        };
    }

    QNetworkRequest request { QUrl(serverUrl) };
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", "Bearer " + key);
    QJsonObject body {
        { "model", image.isEmpty() ? modelName : visionModel },
        { "reasoning_effort", "low" },
        { "messages", QJsonArray {
            QJsonObject { { "role", "system" }, { "content", systemPrompt } },
            QJsonObject { { "role", "user" }, { "content", content } }
        } }
    };
    if (image.isEmpty())
        body["tools"] = QJsonArray { QJsonObject { { "type", "browser_search" } } };
    else
        // Leaves its thinking out of the answer
        body["reasoning_format"] = "hidden";

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
