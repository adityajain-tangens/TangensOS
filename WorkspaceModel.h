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
    enum Role { ColRole = Qt::UserRole, RowRole, ColsRole, RowsRole, ItemRole, FileRole };

    explicit WorkspaceModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Called from QML: when a drag starts, and each time the dragged component is over a new cell
    Q_INVOKABLE void startMove();
    Q_INVOKABLE void moveComponent(int component, int col, int row);

    // Called from QML when something is dropped on the workspace. Adds a component of this
    // size holding this item and file, at the cell (col, row) or the nearest free spot to it.
    // Does nothing and returns false if that cell is already covered by a component.
    Q_INVOKABLE bool addComponent(const QString &item, const QString &file, int col, int row, int cols, int rows);

private:
    QRect nearestFreeSpot(const QRect &component, const QList<QRect> &taken) const;

    static constexpr int columns = 12;

    // Each component as a rectangle of cells: x = col, y = row, width = cols, height = rows
    QList<QRect> m_components;
    // Where every component was when the drag started
    QList<QRect> m_atStart;
    // What sits inside each component, in the same order as m_components
    QList<QString> m_items;
    // The file each component's item shows, if it shows one (like ImageItem), in the same order
    QList<QString> m_files;
};