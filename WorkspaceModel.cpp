#include "WorkspaceModel.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>
#include <algorithm>
#include <limits>

WorkspaceModel::WorkspaceModel(QObject *parent)
    : QAbstractListModel(parent)
{
    // Save a moment after anything changes, and before the app quits
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(500);
    connect(&m_saveTimer, &QTimer::timeout, this, &WorkspaceModel::save);
    connect(this, &QAbstractItemModel::dataChanged, &m_saveTimer, qOverload<>(&QTimer::start));
    connect(this, &QAbstractItemModel::rowsInserted, &m_saveTimer, qOverload<>(&QTimer::start));
    connect(this, &QAbstractItemModel::rowsRemoved, &m_saveTimer, qOverload<>(&QTimer::start));
    connect(qApp, &QCoreApplication::aboutToQuit, this, [this] { if (m_saveTimer.isActive()) save(); });

    // The workspace saved last time. With none, it starts empty.
    QFile saved(savePath());
    if (saved.open(QIODevice::ReadOnly))
        fromJson(QJsonDocument::fromJson(saved.readAll()).object());
}

// Where the workspace is saved: in the app's own data folder, like
// ~/Library/Application Support/appTangens/workspace.json
QString WorkspaceModel::savePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/workspace.json";
}

void WorkspaceModel::save()
{
    m_saveTimer.stop();
    QDir().mkpath(QFileInfo(savePath()).path());
    // Written to a temporary file first, then swapped in, so a crash never leaves half a file
    QSaveFile file(savePath());
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
QJsonObject WorkspaceModel::toJson() const
{
    QJsonArray components;
    for (int i = 0; i < m_components.size(); ++i) {
        const QRect area = m_components.at(i);
        const QString item = m_items.at(i);
        QJsonObject component {
            { "type", item },
            { "x", area.x() }, { "y", area.y() }, { "width", area.width() }, { "height", area.height() },
        };
        const QPointF point = m_scrolls.at(i).toPointF();

        if (item == "WebViewItem") {
            component["url"] = m_texts.at(i);
            component["scroll"] = QJsonObject { { "x", point.x() }, { "y", point.y() } };
        } else if (item == "TextFieldItem") {
            component["text"] = m_texts.at(i);
            component["scroll"] = QJsonObject { { "x", point.x() }, { "y", point.y() } };
        } else if (item == "GridItem") {
            // Each file's position is kept by its URL (see GridItem.qml)
            const QVariantMap scrolls = m_scrolls.at(i).toMap();
            QJsonArray files;
            for (const QString &file : m_files.at(i).split('\n')) {
                QJsonObject json;
                writeFile(json, file, scrolls.value(file));
                files.append(json);
            }
            component["files"] = files;
        } else if (!m_files.at(i).isEmpty()) {
            writeFile(component, m_files.at(i), m_scrolls.at(i));
        }
        components.append(component);
    }
    return { { "components", components } };
}

// Puts a file's path in `json`, and how far it has played (a video) or is scrolled (a PDF), if it's known
void WorkspaceModel::writeFile(QJsonObject &json, const QString &file, const QVariant &scroll)
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
QVariant WorkspaceModel::readScroll(const QJsonObject &json)
{
    if (json.contains("position"))
        return QPointF(0, json["position"].toDouble());
    if (json.contains("scroll"))
        return QPointF(json["scroll"]["x"].toDouble(), json["scroll"]["y"].toDouble());
    return {};
}

// Puts back a workspace saved by toJson()
void WorkspaceModel::fromJson(const QJsonObject &json)
{
    for (const QJsonValue &value : json["components"].toArray()) {
        const QJsonObject component = value.toObject();
        m_components.append(QRect(component["x"].toInt(), component["y"].toInt(),
                                  component["width"].toInt(), component["height"].toInt()));
        m_items.append(component["type"].toString());
        m_texts.append(component.contains("url") ? component["url"].toString() : component["text"].toString());

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
            m_files.append(files.join('\n'));
            m_scrolls.append(scrolls);
        } else {
            m_files.append(component.contains("path") ? QUrl::fromLocalFile(component["path"].toString()).toString() : QString());
            m_scrolls.append(readScroll(component));
        }
    }
    m_atStart = m_components;
}

int WorkspaceModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_components.size();
}

QVariant WorkspaceModel::data(const QModelIndex &index, int role) const
{
    switch (role) {
    case AreaRole: return m_components.at(index.row());
    case ItemRole: return m_items.at(index.row());
    case FileRole: return m_files.at(index.row());
    case TextRole: return m_texts.at(index.row());
    case ScrollRole: return m_scrolls.at(index.row());
    }
    return {};
}

// The names QML uses for each value
QHash<int, QByteArray> WorkspaceModel::roleNames() const
{
    return { { AreaRole, "area" }, { ItemRole, "item" }, { FileRole, "file" }, { TextRole, "text" }, { ScrollRole, "scroll" } };
}

bool WorkspaceModel::addComponent(const QString &item, const QString &file, int x, int y, const QString &text,
                                  const QVariant &scroll)
{
    const QPoint spot(x, y);
    for (const QRect &other : m_components) {
        if (other.contains(spot))
            return false;
    }

    const QRect component = nearestFreeSpot(QRect(x, y, newWidth, newHeight), m_components);

    const int at = m_components.size();
    beginInsertRows({}, at, at);
    m_components.append(component);
    m_atStart.append(component);
    m_items.append(item);
    m_files.append(file);
    m_texts.append(text);
    m_scrolls.append(scroll);
    endInsertRows();
    emit boundsChanged();
    return true;
}

void WorkspaceModel::replaceItem(int component, const QString &item, const QString &file)
{
    m_items[component] = item;
    m_files[component] = file;
    emit dataChanged(index(component), index(component), { ItemRole, FileRole });
}

void WorkspaceModel::setText(int component, const QString &text)
{
    if (m_texts.at(component) == text)
        return;
    m_texts[component] = text;
    emit dataChanged(index(component), index(component), { TextRole });
}

void WorkspaceModel::setScroll(int component, const QVariant &scroll)
{
    if (m_scrolls.at(component) == scroll)
        return;
    m_scrolls[component] = scroll;
    emit dataChanged(index(component), index(component), { ScrollRole });
}

void WorkspaceModel::removeComponent(int component)
{
    beginRemoveRows({}, component, component);
    m_components.removeAt(component);
    m_items.removeAt(component);
    m_files.removeAt(component);
    m_texts.removeAt(component);
    m_scrolls.removeAt(component);
    endRemoveRows();
    emit boundsChanged();
}

void WorkspaceModel::startChange()
{
    m_atStart = m_components;
}

// Moves a component so its top-left corner is at (x, y), keeping its size
void WorkspaceModel::moveComponent(int component, int x, int y)
{
    QRect moved = m_atStart.at(component);
    moved.moveTo(x, y);
    place(component, moved);
}

// Moves one corner of a component by (dx, dy) from where it was when the resize started.
// The opposite corner stays put, and it never gets smaller than the minimum size.
void WorkspaceModel::resizeComponent(int component, bool atLeft, bool atTop, int dx, int dy)
{
    const QRect start = m_atStart.at(component);
    int left = start.x();
    int top = start.y();
    int right = start.x() + start.width();
    int bottom = start.y() + start.height();

    if (atLeft)
        left = qMin(left + dx, right - minWidth);
    else
        right = qMax(right + dx, left + minWidth);
    if (atTop)
        top = qMin(top + dy, bottom - minHeight);
    else
        bottom = qMax(bottom + dy, top + minHeight);

    place(component, QRect(left, top, right - left, bottom - top));
}

// Puts one component at a new rectangle. Any component now too close to it moves to the
// nearest free spot. Always works from where things were when the change started, so a pushed
// component goes back if the changed one moves away again.
void WorkspaceModel::place(int component, const QRect &moved)
{
    // First everything that stays: the changed component, and every component not too close to it
    QList<QRect> result = m_atStart;
    result[component] = moved;
    QList<QRect> taken { moved };
    for (int i = 0; i < result.size(); ++i) {
        if (i != component && !tooClose(result.at(i), moved))
            taken.append(result.at(i));
    }

    // Then each one that is, into the nearest spot that's still free
    for (int i = 0; i < result.size(); ++i) {
        if (i != component && tooClose(result.at(i), moved)) {
            result[i] = nearestFreeSpot(result.at(i), taken);
            taken.append(result.at(i));
        }
    }

    m_components = result;
    emit dataChanged(index(0), index(m_components.size() - 1), { AreaRole });
    emit boundsChanged();
}

// The smallest rectangle holding every component
QRect WorkspaceModel::bounds() const
{
    QRect all;
    for (const QRect &component : m_components)
        all |= component;
    return all;
}

// True when two components overlap, or are less than the gap apart
bool WorkspaceModel::tooClose(const QRect &a, const QRect &b)
{
    return a.adjusted(-gap, -gap, gap, gap).intersects(b);
}

// The free spot of the same size that's closest to where the component is now.
// The closest spot either is where it is, or touches the gap around other components on one or two sides.
// So only these are tried: its own x and y, and the x and y that put it just left, right, above or below each other one.
QRect WorkspaceModel::nearestFreeSpot(const QRect &component, const QList<QRect> &taken)
{
    QList<int> xs { component.x() };
    QList<int> ys { component.y() };
    for (const QRect &other : taken) {
        xs << other.x() - gap - component.width() << other.x() + other.width() + gap;
        ys << other.y() - gap - component.height() << other.y() + other.height() + gap;
    }

    QRect best;
    qint64 bestDistance = std::numeric_limits<qint64>::max();
    for (int x : xs) {
        for (int y : ys) {
            const QRect spot(x, y, component.width(), component.height());
            const qint64 dx = x - component.x();
            const qint64 dy = y - component.y();
            const qint64 distance = dx * dx + dy * dy;
            if (distance < bestDistance
                && std::none_of(taken.begin(), taken.end(), [&](const QRect &other) { return tooClose(other, spot); })) {
                best = spot;
                bestDistance = distance;
            }
        }
    }
    return best;
}
