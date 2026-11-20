#pragma once

#include <QAbstractListModel>
#include <QRect>
#include <QtQml/qqmlregistration.h>

// The components on the workspace and where each one sits on it.
// Positions and sizes are in pixels, at full size. The workspace has no end in any direction, so a
// position can be negative. Components never overlap, and always keep a small gap between them.
class WorkspaceModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    // The smallest rectangle holding every component
    Q_PROPERTY(QRect bounds READ bounds NOTIFY boundsChanged)

public:
    enum Role { AreaRole = Qt::UserRole, ItemRole, FileRole, TextRole };

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
    // holding this item and file (or starting text), with its top-left corner at (x, y) or at the nearest
    // free spot to it. Does nothing and returns false if (x, y) is already on a component.
    Q_INVOKABLE bool addComponent(const QString &item, const QString &file, int x, int y, const QString &text = {});

    // Called from QML when a file is dropped on a DropZoneItem: the component
    // now holds this item showing this file instead
    Q_INVOKABLE void replaceItem(int component, const QString &item, const QString &file);

    // Called from QML when a component's X button is clicked: takes it off the workspace
    Q_INVOKABLE void removeComponent(int component);

    QRect bounds() const;

signals:
    void boundsChanged();

private:
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
};
