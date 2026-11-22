#include "SaveManager.h"
#include "WorkspaceModel.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>

SaveManager::SaveManager(QObject *parent)
    : QObject(parent)
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(500);
    connect(&m_saveTimer, &QTimer::timeout, this, &SaveManager::save);
    // Anything not written yet is written before the app quits
    connect(qApp, &QCoreApplication::aboutToQuit, this, [this] { if (m_saveTimer.isActive()) save(); });
}

SaveManager *SaveManager::instance()
{
    static SaveManager *manager = new SaveManager(qApp);
    return manager;
}

SaveManager *SaveManager::create(QQmlEngine *, QJSEngine *)
{
    // The app owns it, not the QML engine, so the engine never deletes it
    QJSEngine::setObjectOwnership(instance(), QJSEngine::CppOwnership);
    return instance();
}

QString SaveManager::path() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/workspace.json";
}

void SaveManager::watch(WorkspaceModel *model)
{
    m_model = model;

    // The workspace saved last time. With none, it starts empty.
    QFile saved(path());
    if (saved.open(QIODevice::ReadOnly))
        fromJson(QJsonDocument::fromJson(saved.readAll()).object());

    connect(model, &QAbstractItemModel::dataChanged, this, &SaveManager::saveLater);
    connect(model, &QAbstractItemModel::rowsInserted, this, &SaveManager::saveLater);
    connect(model, &QAbstractItemModel::rowsRemoved, this, &SaveManager::saveLater);
}

void SaveManager::saveLater()
{
    m_saveTimer.start();
}

void SaveManager::save()
{
    m_saveTimer.stop();
    if (m_model == nullptr)
        return;
    QDir().mkpath(QFileInfo(path()).path());
    // Written to a temporary file first, then swapped in, so a crash never leaves half a file
    QSaveFile file(path());
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(toJson()).toJson());
    file.commit();
}

// The whole workspace as JSON, like:
// { "components": [
//     { "type": "WebViewItem", "x": 0, "y": 0, "width": 366, "height": 366,
//       "url": "https://qt.io", "scroll": { "x": 0, "y": 120 } },
//     { "type": "TextFieldItem", ..., "text": "<html>...", "scroll": { "x": 0, "y": 0 } },
//     { "type": "ImageItem", ..., "path": "/Users/me/photo.png" },
//     { "type": "VideoItem", ..., "path": "/Users/me/clip.mp4", "position": 12500 },   (how far it has played, in ms)
//     { "type": "PDFItem", ..., "path": "/Users/me/report.pdf", "scroll": { "x": 0, "y": 1840 } },   (in PDF points)
//     { "type": "GridItem", ..., "files": [ { "path": "/Users/me/a.png" },
//                                           { "path": "/Users/me/b.mp4", "position": 3000 },
//                                           { "path": "/Users/me/c.pdf", "scroll": { "x": 0, "y": 600 } } ] },
//     { "type": "DropZoneItem", ... }   (and "AppSnapshotItem", and "" for an empty one)
// ] }
// The type is the name of the item's .qml file. Files are saved as paths on disk, not URLs.
QJsonObject SaveManager::toJson() const
{
    const WorkspaceModel &model = *m_model;
    QJsonArray components;
    for (int i = 0; i < model.m_components.size(); ++i) {
        const QRect area = model.m_components.at(i);
        const QString item = model.m_items.at(i);
        const QString file = model.m_files.at(i);
        const QVariant scroll = model.m_scrolls.at(i);
        QJsonObject component {
            { "type", item },
            { "x", area.x() }, { "y", area.y() }, { "width", area.width() }, { "height", area.height() },
        };
        const QJsonObject point { { "x", scroll.toPointF().x() }, { "y", scroll.toPointF().y() } };

        if (item == "WebViewItem") {
            component["url"] = model.m_texts.at(i);
            component["scroll"] = point;
        } else if (item == "TextFieldItem") {
            component["text"] = model.m_texts.at(i);
            component["scroll"] = point;
        } else if (item == "GridItem") {
            // Each file's position is kept by its URL (see GridItem.qml)
            const QVariantMap scrolls = scroll.toMap();
            QJsonArray files;
            for (const QString &one : file.split('\n')) {
                QJsonObject json;
                writeFile(json, one, scrolls.value(one));
                files.append(json);
            }
            component["files"] = files;
        } else if (!file.isEmpty()) {
            writeFile(component, file, scroll);
        }
        components.append(component);
    }
    return { { "components", components } };
}

// Puts a file's path in `json`, and how far it has played (a video) or is scrolled (a PDF), if it's known
void SaveManager::writeFile(QJsonObject &json, const QString &file, const QVariant &scroll)
{
    json["path"] = QUrl(file).toLocalFile();
    if (!scroll.isValid())
        return;
    const QPointF point = scroll.toPointF();
    if (file.endsWith(".pdf", Qt::CaseInsensitive))
        json["scroll"] = QJsonObject { { "x", point.x() }, { "y", point.y() } };
    else
        json["position"] = qRound64(point.y());
}

// How far what `json` describes is scrolled, or none. A video's position is kept as its scroll, like VideoItem does.
QVariant SaveManager::readScroll(const QJsonObject &json)
{
    if (json.contains("position"))
        return QPointF(0, json["position"].toDouble());
    if (json.contains("scroll"))
        return QPointF(json["scroll"]["x"].toDouble(), json["scroll"]["y"].toDouble());
    return {};
}

// Puts back a workspace saved by toJson(). Only called before anything shows the model.
void SaveManager::fromJson(const QJsonObject &json)
{
    WorkspaceModel &model = *m_model;
    for (const QJsonValue &value : json["components"].toArray()) {
        const QJsonObject component = value.toObject();
        model.m_components.append(QRect(component["x"].toInt(), component["y"].toInt(),
                                        component["width"].toInt(), component["height"].toInt()));
        model.m_items.append(component["type"].toString());
        model.m_texts.append(component.contains("url") ? component["url"].toString() : component["text"].toString());

        if (component.contains("files")) {
            // A grid: its files, and each one's position by its URL
            QStringList files;
            QVariantMap scrolls;
            for (const QJsonValue &fileValue : component["files"].toArray()) {
                const QString file = QUrl::fromLocalFile(fileValue["path"].toString()).toString();
                files.append(file);
                const QVariant scroll = readScroll(fileValue.toObject());
                if (scroll.isValid())
                    scrolls[file] = scroll;
            }
            model.m_files.append(files.join('\n'));
            model.m_scrolls.append(scrolls);
        } else {
            model.m_files.append(component.contains("path") ? QUrl::fromLocalFile(component["path"].toString()).toString() : QString());
            model.m_scrolls.append(readScroll(component));
        }
    }
    model.m_atStart = model.m_components;
}
