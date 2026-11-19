#pragma once

#include <QAbstractListModel>
#include <QRect>
#include <QtQml/qqmlregistration.h>

// The components on the workspace and where each one sits on the grid.
// Positions and sizes are in grid cells. Components never overlap.
class WorkspaceModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    enum Role { ColRole = Qt::UserRole, RowRole, ColsRole, RowsRole, ItemRole, FileRole, TextRole };

    explicit WorkspaceModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Called from QML: when a move or resize starts, and each time it reaches a new cell
    Q_INVOKABLE void startChange();
    Q_INVOKABLE void moveComponent(int component, int col, int row);
    Q_INVOKABLE void resizeComponent(int component, int left, int top, int right, int bottom);

    // Called from QML when something is dropped on the workspace, or a note is added. Adds a component
    // of this size holding this item and file (or starting text), at the cell (col, row) or the nearest
    // free spot to it. Does nothing and returns false if that cell is already covered by a component.
    Q_INVOKABLE bool addComponent(const QString &item, const QString &file, int col, int row, int cols, int rows,
                                  const QString &text = {});

    // Called from QML when a file is dropped on a DropZoneItem: the component
    // now holds this item showing this file instead
    Q_INVOKABLE void replaceItem(int component, const QString &item, const QString &file);

    // Called from QML when a component's X button is clicked: takes it off the workspace
    Q_INVOKABLE void removeComponent(int component);

private:
    void place(int component, const QRect &moved);
    QRect nearestFreeSpot(const QRect &component, const QList<QRect> &taken) const;

    static constexpr int columns = 12;
    // The smallest a component can be
    static constexpr int minCols = 2;
    static constexpr int minRows = 2;

    // Each component as a rectangle of cells: x = col, y = row, width = cols, height = rows
    QList<QRect> m_components;
    // Where every component was when the drag started
    QList<QRect> m_atStart;
    // What sits inside each component, in the same order as m_components
    QList<QString> m_items;
    // The file each component's item shows, if it shows one (like ImageItem), in the same order
    QList<QString> m_files;
    // The text each component's item starts with, if it holds text (like TextFieldItem), in the same order
    QList<QString> m_texts;
};