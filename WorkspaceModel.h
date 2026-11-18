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
    enum Role { ColRole = Qt::UserRole, RowRole, ColsRole, RowsRole, ItemRole };

    explicit WorkspaceModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Called from QML: when a move or resize starts, and each time it reaches a new cell
    Q_INVOKABLE void startChange();
    Q_INVOKABLE void moveComponent(int component, int col, int row);
    Q_INVOKABLE void resizeComponent(int component, int left, int top, int right, int bottom);

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
};