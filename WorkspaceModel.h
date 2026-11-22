#pragma once

#include <QAbstractListModel>
#include <QJsonObject>
#include <QPointF>
#include <QRect>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// The components on the workspace and where each one sits on it.
// Positions and sizes are in pixels, at full size. The workspace has no end in any direction, so a
// position can be negative. Components never overlap, and always keep a small gap between them.
// The whole workspace is saved as JSON in the app's own data folder a moment after anything changes,
// and loaded from there when the app starts (see toJson() and fromJson()).
class WorkspaceModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    // The smallest rectangle holding every component
    Q_PROPERTY(QRect bounds READ bounds NOTIFY boundsChanged)

public:
    enum Role { AreaRole = Qt::UserRole, ItemRole, FileRole, TextRole, ScrollRole };

    explicit WorkspaceModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Called from QML: when a move or resize starts, and each time it changes.
    // A resize moves the corner given by atLeft and atTop by (dx, dy) from where it started.
    Q_INVOKABLE void startChange();
    Q_INVOKABLE void moveComponent(int component, int x, int y);
    Q_INVOKABLE void resizeComponent(int component, bool atLeft, bool atTop, int dx, int dy);

    // Called from QML when something is dropped on the workspace, or a note is added. Adds a component
    // holding this item and file (or starting text, and how far it's scrolled), with its top-left corner at
    // (x, y) or at the nearest free spot to it. Does nothing and returns false if (x, y) is already on a component.
    Q_INVOKABLE bool addComponent(const QString &item, const QString &file, int x, int y, const QString &text = {},
                                  const QVariant &scroll = {});

    // Called from QML when a file is dropped on a DropZoneItem: the component
    // now holds this item showing this file instead
    Q_INVOKABLE void replaceItem(int component, const QString &item, const QString &file);

    // Called from QML when a component's X button is clicked: takes it off the workspace
    Q_INVOKABLE void removeComponent(int component);

    // Called from QML when what's inside a component changes: the text typed in a TextFieldItem
    // (as rich text, with its formatting), or the page a WebViewItem shows. And when it's scrolled: a point,
    // or for a GridItem, a point for each of its files that has one, by the file's URL.
    Q_INVOKABLE void setText(int component, const QString &text);
    Q_INVOKABLE void setScroll(int component, const QVariant &scroll);

    // Writes the workspace to its file now, instead of waiting for the timer
    Q_INVOKABLE void save();

    QRect bounds() const;

signals:
    void boundsChanged();

private:
    QJsonObject toJson() const;
    void fromJson(const QJsonObject &json);
    static QString savePath();
    static void writeFile(QJsonObject &json, const QString &file, const QVariant &scroll);
    static QVariant readScroll(const QJsonObject &json);

    void place(int component, const QRect &moved);
    static bool tooClose(const QRect &a, const QRect &b);
    static QRect nearestFreeSpot(const QRect &component, const QList<QRect> &taken);

    // The space kept between components
    static constexpr int gap = 12;
    // The smallest a component can be
    static constexpr int minWidth = 114;
    static constexpr int minHeight = 72;
    // The size of a new component
    static constexpr int newWidth = 240;
    static constexpr int newHeight = 240;

    // Where each component is, as a rectangle
    QList<QRect> m_components;
    // Where every component was when the change started
    QList<QRect> m_atStart;
    // What sits inside each component, in the same order as m_components
    QList<QString> m_items;
    // The file each component's item shows, if it shows one (like ImageItem), in the same order
    QList<QString> m_files;
    // The text each component's item starts with, if it holds text (like TextFieldItem), in the same order
    QList<QString> m_texts;
    // How far each component's item is scrolled, if it scrolls (like WebViewItem), in the same order.
    // For a VideoItem, how far it has played in milliseconds, as y. For a GridItem, a map from each
    // file's URL to its own. Empty when there's none.
    QList<QVariant> m_scrolls;

    // Saves a moment after the last change, so a drag doesn't write the file at every step
    QTimer m_saveTimer;
};
