#include "AIClient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>

// which AI to use: true for Gemini, false for Groq
static const bool useGemini = true;

// Groq settings
static const char *serverUrl = "https://api.groq.com/openai/v1/chat/completions";
static const char *modelName = "openai/gpt-oss-120b";

// Gemini settings
static const char *geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/";
static const char *geminiModel = "gemini-3.6-flash";

// step 1: find facts on the web, as plain notes
static const char *researchPrompt = R"(You help a UI-building assistant by gathering facts.
You get a workspace and a request. If the request needs current facts, prices, availability or links, search the web.
Reply with short plain-text notes: names, numbers, dates and source URLs. No UI, no JSON.
If nothing needs looking up, reply exactly: none)";

// step 2: turn the request and notes into workspace edits
static const char *systemPrompt = R"(You build and edit a workspace made of parts. Reply ONLY with one JSON object.

You get the current parts, recent history, a new request and research notes. Reply with:
{"say":"one short sentence about what you changed","intent":["compare","plan",...],"ops":[EDIT,...]}

EDIT is one of:
- {"op":"add","part":{"id":"short-id","title":"Part title","content":NODE},"after":"id"} ("after" is optional, default is the end)
- {"op":"replace","id":"existing-id","title":"optional new title","content":NODE}
- {"op":"remove","id":"existing-id"}

Rules:
- Change only what the request needs. Never touch parts the request is not about.
- If the request refines an existing part, replace it instead of adding a similar one.
- One reply may contain several edits. Ids are short lowercase words like "venues" or "budget".
- intent uses words like discover, research, compare, decide, plan, organize, create, schedule, navigate, manage.
- Use the research notes for facts and links. Don't invent prices or URLs.

NODE is a UI tree. Every node is {"type": ..., ...}. Allowed types:
- "Column": {"type":"Column","children":[nodes]} stacks children vertically
- "Row": {"type":"Row","children":[nodes]} puts children side by side (2-3 max)
- "Card": {"type":"Card","children":[nodes]} a box around its children
- "Text": {"type":"Text","text":"...","style":"title"|"body"|"caption"} one line or paragraph, never use \n, use separate Text nodes instead
- "Button": {"type":"Button","label":"...","action":ACTION}
- "Image": {"type":"Image","url":"https://..."} only use real image URLs from the notes, otherwise skip images
ACTION is {"type":"ask","prompt":"follow-up request"} or {"type":"open_url","url":"https://..."}.
Part content should be a Column. Keep parts compact and useful.)";

// the text of the AI's answer
static QString messageText(const QJsonObject &answer)
{
    return answer["choices"].toArray().first()
    .toObject()["message"].toObject()["content"].toString();
}

AIClient::AIClient(QObject *parent)
    : QObject(parent)
{
}

// the text of a Gemini answer, skipping any thinking parts
static QString geminiText(const QJsonObject &answer)
{
    QString text;
    const QJsonArray parts = answer["candidates"].toArray().first()
                                 .toObject()["content"].toObject()["parts"].toArray();
    for (const QJsonValue &part : parts) {
        if (!part["thought"].toBool())
            text += part["text"].toString();
    }
    return text;
}

// a request to Groq with the API key
static QNetworkRequest groqRequest()
{
    QNetworkRequest request { QUrl(serverUrl) };
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", "Bearer " + qgetenv("GROQ_API_KEY"));
    return request;
}

void AIClient::ask(const QString &prompt)
{
    const char *keyName = useGemini ? "GEMINI_API_KEY" : "GROQ_API_KEY";
    if (qgetenv(keyName).isEmpty()) {
        emit failed(QString(keyName) + " is not set");
        return;
    }
    if (useGemini)
        askGemini(prompt);
    else
        research(prompt, 1);
}

// Gemini can search and reply in JSON in one call
void AIClient::askGemini(const QString &prompt)
{
    setStatus("Thinking…");
    const QJsonObject body {
        { "systemInstruction", QJsonObject { { "parts", QJsonArray { QJsonObject { { "text", systemPrompt } } } } } },
        { "contents", QJsonArray { QJsonObject {
                         { "role", "user" },
                         { "parts", QJsonArray { QJsonObject { { "text", prompt
                                                                       + "\n\nResearch notes:\nnone yet. Use Google Search when the request needs current facts, prices or links." } } } }
                     } } },
   //     { "tools", QJsonArray { QJsonObject { { "google_search", QJsonObject {} } } } },
        { "generationConfig", QJsonObject { { "responseMimeType", "application/json" } } }
    };

    QNetworkRequest request { QUrl(QString(geminiUrl) + geminiModel + ":generateContent") };
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("x-goog-api-key", qgetenv("GEMINI_API_KEY"));

    post(request, body, [this](const QJsonObject &answer, const QString &error) {
        setStatus("");
        if (!error.isEmpty()) {
            emit failed(error);
            return;
        }
        emit replyReady(geminiText(answer));
    });
}

// step 1: search the web and write plain notes
void AIClient::research(const QString &prompt, int retries)
{
    setStatus("Searching…");
    const QJsonObject body {
        { "model", modelName },
        { "reasoning_effort", "low" },
        { "tools", QJsonArray { QJsonObject { { "type", "browser_search" } } } },
        { "messages", QJsonArray {
                         QJsonObject { { "role", "system" }, { "content", researchPrompt } },
                         QJsonObject { { "role", "user" }, { "content", prompt } }
                     } }
    };

    post(groqRequest(), body, [this, prompt, retries](const QJsonObject &answer, const QString &error) {
        // the model sometimes makes a broken search call, so try once more
        const QString code = answer["error"].toObject()["code"].toString();
        if (code == "tool_use_failed" && retries > 0) {
            research(prompt, retries - 1);
            return;
        }
        // build anyway, just without fresh facts
        build(prompt, error.isEmpty() ? messageText(answer) : "none (search failed)");
    });
}

// step 2: JSON mode, no tools, so the reply is always valid JSON
void AIClient::build(const QString &prompt, const QString &notes)
{
    setStatus("Building…");
    const QJsonObject body {
        { "model", modelName },
        { "reasoning_effort", "low" },
        { "response_format", QJsonObject { { "type", "json_object" } } },
        { "messages", QJsonArray {
                         QJsonObject { { "role", "system" }, { "content", systemPrompt } },
                         QJsonObject { { "role", "user" }, { "content", prompt + "\n\nResearch notes:\n" + notes } }
                     } }
    };

    post(groqRequest(), body, [this](const QJsonObject &answer, const QString &error) {
        setStatus("");
        if (!error.isEmpty()) {
            emit failed(error);
            return;
        }
        emit replyReady(messageText(answer));
    });
}

// sends one request and hands back the answer, or an error message
void AIClient::post(const QNetworkRequest &request, const QJsonObject &body,
                    const std::function<void(const QJsonObject &, const QString &)> &done)
{
    QNetworkReply *reply = m_network.post(request, QJsonDocument(body).toJson());
    connect(reply, &QNetworkReply::finished, this, [reply, done]() {
        reply->deleteLater();
        const QJsonObject answer = QJsonDocument::fromJson(reply->readAll()).object();
        QString error;
        if (reply->error() != QNetworkReply::NoError) {
            error = answer["error"].toObject()["message"].toString();
            if (error.isEmpty())
                error = reply->errorString();
        }
        done(answer, error);
    });
}

void AIClient::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    const bool wasBusy = busy();
    m_status = status;
    emit statusChanged();
    if (wasBusy != busy())
        emit busyChanged();
}