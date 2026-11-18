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
    enum Role { ColRole = Qt::UserRole, RowRole, ColsRole, RowsRole };

    explicit WorkspaceModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Called from QML: when a drag starts, and each time the dragged component is over a new cell
    Q_INVOKABLE void startMove();
    Q_INVOKABLE void moveComponent(int component, int col, int row);

private:
    QRect nearestFreeSpot(const QRect &component, const QList<QRect> &taken) const;

    static constexpr int columns = 12;

    // Each component as a rectangle of cells: x = col, y = row, width = cols, height = rows
    QList<QRect> m_components;
    // Where every component was when the drag started
    QList<QRect> m_atStart;
};