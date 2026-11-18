#include "AIClient.h"

#include <QDebug>
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
You send data only. The app decides how every part looks.

You get the current parts, facts, recent history, a new request and research notes. Reply with:
{"say":"one short sentence about what you changed","intent":["compare"],"edits":[EDIT,...]}

A part of kind "options" is a set of things with the same details each: products, places, people, films, anything to compare, choose from or keep track of. A guest list is an options part too. Every item has the same fields.
PART: {"id":"laptops","kind":"options","title":"Laptops","look":"cards","fields":[FIELD,...],"items":[ITEM,...]}
FIELD: {"id":"price","label":"Price","type":"money"} one detail that every item has. type is text, number, money, rating or link.
ITEM: {"id":"air","name":"MacBook Air 13","line":"Thin, quiet, long battery","badge":"Best value","cells":[CELL,...]}
CELL: {"field":"price","text":"$1,099","number":1099} one item's value for one field.
- "text" is what is shown. Keep it short.
- "number" is the same value as a plain number. Send it for number, money and rating fields.
- "url" is only for link fields.
- "name" is not a field. "line" is one short line that tells this item apart.
- "badge" is 1 to 3 words. At most one item in a part has a badge: the one that clearly stands out. Leave it out on all the others.
- "picked": true in the current parts marks the item the user chose. Only the user can set it. Take it into account.
- "note" is a short explanation attached to one cell or to one item. Leave it out unless you are answering a question.

EDIT is one of:
- {"edit":"set_part","part":PART,"after":"id"} adds a new part ("after" is optional, default is the end). For a part that already exists, send only its id with a new title or look. Its fields and items cannot be changed this way.
- {"edit":"remove_part","id":"laptops"}
- {"edit":"set_field","partId":"laptops","field":FIELD} adds a field, or changes its label or type.
- {"edit":"remove_field","partId":"laptops","id":"weight"}
- {"edit":"set_item","partId":"laptops","item":ITEM} adds an item. For an item that already exists, only what you send changes: send its id and just the cells that are new or different.
- {"edit":"remove_item","partId":"laptops","id":"air"}
- {"edit":"set_fact","fact":FACT} adds a fact, or changes the label or text of one that exists.
- {"edit":"remove_fact","id":"budget"}

Facts are a few key values about the whole workspace, shown at the top.
FACT: {"id":"budget","label":"Budget","text":"$1,500"}
- A fact is something the user stated or decided: a budget, a date, a number of people, what it is for, or an item they picked.
- A fact is about the whole workspace, never one item's details.
- Never invent or guess a fact. A value worked out from other facts, like what is left of a budget, is fine. Keep it right when those facts change.
- Keep label and text short. At most 6 facts.
- When told the user picked an item, add a fact for the choice: the label says what kind of thing, the text is its name and main value. When told they undid a pick, remove that fact. Send no part, field or item edits for these.

Rules:
- Change only what the request needs. Never resend names, cells or items that stay the same.
- To add a detail to a comparison: one set_field, then one set_item per item with only the new cell. Send the set_field first.
- A new comparison has 3 items unless the request says otherwise, and 3 to 5 fields. Put the price first when there is one.
- look is "cards" by default. Use "table" when there are many fields or the user asks for a table.
- Ids are short lowercase words like "laptops", "price" or "air".
- A request that starts with About the item "..." is about that one item. Change only that item unless the request says otherwise.
- Where the answer to a question goes. Pick the first that fits:
  1. One short sentence is enough: answer in "say" and send no edits.
  2. It is about one value of one item, like its area or its battery: put it in "note" on that cell. Send the item's id and one cell with only "field" and "note": {"edit":"set_item","partId":"hotels","item":{"id":"park","cells":[{"field":"area","note":"..."}]}}
  3. It is about one item as a whole: put it in "note" on the item: {"edit":"set_item","partId":"hotels","item":{"id":"park","note":"..."}}
  4. It is a detail every item has: add a field.
- A note is 1 to 4 sentences of plain text. In "say" only tell the user where you put it, don't repeat it. A new note replaces the old one. To remove a note, send "note":"".
- Every cell of a new item needs "text". Only leave "text" out when you add a note to a cell that already exists.
- If the request cannot be shown as a set of things or a fact, send no edits and say so in "say".
- intent uses words like discover, research, compare, decide, plan, organize, create, schedule, navigate, manage.
- Use the research notes for facts and links. Don't invent URLs.)";

// helpers for writing the reply schema
static QJsonObject schemaChoice(const QJsonArray &options)
{
    return QJsonObject { { "type", "STRING" }, { "enum", options } };
}

static QJsonObject schemaList(const QJsonObject &entry)
{
    return QJsonObject { { "type", "ARRAY" }, { "items", entry } };
}

// order lists the properties the way the instructions show them
static QJsonObject schemaObject(const QJsonArray &order, const QJsonObject &properties, const QJsonArray &required)
{
    return QJsonObject {
        { "type", "OBJECT" },
        { "properties", properties },
        { "propertyOrdering", order },
        { "required", required }
    };
}

// the exact shape Gemini's reply must have
static QJsonObject replySchema()
{
    const QJsonObject text { { "type", "STRING" } };
    const QJsonObject number { { "type", "NUMBER" } };

    const QJsonObject field = schemaObject({ "id", "label", "type" }, {
                                                                        { "id", text },
                                                                        { "label", text },
                                                                        { "type", schemaChoice({ "text", "number", "money", "rating", "link" }) }
                                                                    }, { "id" });

    const QJsonObject cell = schemaObject({ "field", "text", "number", "url", "note" }, {
                                                                                          { "field", text },
                                                                                          { "text", text },
                                                                                          { "number", number },
                                                                                          { "url", text },
                                                                                          { "note", text }
                                                                                      }, { "field" });

    const QJsonObject item = schemaObject({ "id", "name", "line", "badge", "note", "cells" }, {
                                                                                                { "id", text },
                                                                                                { "name", text },
                                                                                                { "line", text },
                                                                                                { "badge", text },
                                                                                                { "note", text },
                                                                                                { "cells", schemaList(cell) }
                                                                                            }, { "id" });

    const QJsonObject part = schemaObject({ "id", "kind", "title", "look", "fields", "items" }, {
                                                                                                  { "id", text },
                                                                                                  { "kind", schemaChoice({ "options" }) },
                                                                                                  { "title", text },
                                                                                                  { "look", schemaChoice({ "cards", "table", "list" }) },
                                                                                                  { "fields", schemaList(field) },
                                                                                                  { "items", schemaList(item) }
                                                                                              }, { "id" });

    const QJsonObject fact = schemaObject({ "id", "label", "text" }, {
                                                                       { "id", text },
                                                                       { "label", text },
                                                                       { "text", text }
                                                                   }, { "id" });

    const QJsonObject edit = schemaObject({ "edit", "partId", "id", "part", "after", "field", "item", "fact" }, {
                                                                                                                  { "edit", schemaChoice({ "set_part", "remove_part", "set_field", "remove_field", "set_item", "remove_item",
                                                                                                                                         "set_fact", "remove_fact" }) },
                                                                                                                  { "partId", text },
                                                                                                                  { "id", text },
                                                                                                                  { "part", part },
                                                                                                                  { "after", text },
                                                                                                                  { "field", field },
                                                                                                                  { "item", item },
                                                                                                                  { "fact", fact }
                                                                                                              }, { "edit" });

    return schemaObject({ "say", "intent", "edits" }, {
                                                        { "say", text },
                                                        { "intent", schemaList(text) },
                                                        { "edits", schemaList(edit) }
                                                    }, { "say", "edits" });
}

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

// one call, with the schema so the reply always has the right shape
void AIClient::askGemini(const QString &prompt)
{
    setStatus("Thinking…");
    const QJsonObject body {
        { "systemInstruction", QJsonObject { { "parts", QJsonArray { QJsonObject { { "text", systemPrompt } } } } } },
        { "contents", QJsonArray { QJsonObject {
                         { "role", "user" },
                         { "parts", QJsonArray { QJsonObject { { "text", prompt + "\n\nResearch notes:\nnone" } } } }
                     } } },
        //     { "tools", QJsonArray { QJsonObject { { "google_search", QJsonObject {} } } } },
        { "generationConfig", QJsonObject {
                                 { "responseMimeType", "application/json" },
                                 { "responseSchema", replySchema() }
                             } }
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
        const QString json = geminiText(answer);
        // shows the raw reply in Application Output
        qDebug().noquote() << "AI reply:" << json;
        emit replyReady(json);
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

// step 2: JSON mode, no tools and no schema
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
        const QString json = messageText(answer);
        qDebug().noquote() << "AI reply:" << json;
        emit replyReady(json);
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