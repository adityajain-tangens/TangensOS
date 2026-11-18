#include "WorkspaceModel.h"

#include <algorithm>
#include <climits>

WorkspaceModel::WorkspaceModel(QObject *parent)
    : QAbstractListModel(parent)
{
    // The starting components: col, row, cols, rows
    m_components = {
        QRect(0, 0, 6, 9),
        QRect(6, 0, 3, 4),
        QRect(9, 0, 3, 4),
        QRect(6, 4, 6, 5),
        QRect(0, 9, 4, 6),
    };
    m_atStart = m_components;

    // What sits inside each component, in the same order as above: the name of a
    // ComponentItem's .qml file, like "TextFieldItem". "" leaves it empty.
    m_items = { "TextFieldItem", "", "", "", "" };
}

int WorkspaceModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_components.size();
}

QVariant WorkspaceModel::data(const QModelIndex &index, int role) const
{
    const QRect &component = m_components.at(index.row());
    switch (role) {
    case ColRole: return component.x();
    case RowRole: return component.y();
    case ColsRole: return component.width();
    case RowsRole: return component.height();
    case ItemRole: return m_items.at(index.row());
    }
    return {};
}

// The names QML uses for each value
QHash<int, QByteArray> WorkspaceModel::roleNames() const
{
    return { { ColRole, "col" }, { RowRole, "row" }, { ColsRole, "cols" }, { RowsRole, "rows" }, { ItemRole, "item" } };
}

void WorkspaceModel::startMove()
{
    m_atStart = m_components;
}

// Puts one component at a new cell. Any component it now covers moves to the nearest free spot.
// Always works from where things were when the drag started, so a pushed component
// goes back if the dragged one moves away again.
void WorkspaceModel::moveComponent(int component, int col, int row)
{
    QRect moved = m_atStart.at(component);
    moved.moveTo(qBound(0, col, columns - moved.width()), qMax(0, row));

    // First everything that stays: the moved component, and every component it doesn't cover
    QList<QRect> result = m_atStart;
    result[component] = moved;
    QList<QRect> taken { moved };
    for (int i = 0; i < result.size(); ++i) {
        if (i != component && !result.at(i).intersects(moved))
            taken.append(result.at(i));
    }

    // Then each covered component, into the nearest spot that's still free
    for (int i = 0; i < result.size(); ++i) {
        if (i != component && result.at(i).intersects(moved)) {
            result[i] = nearestFreeSpot(result.at(i), taken);
            taken.append(result.at(i));
        }
    }

    m_components = result;
    emit dataChanged(index(0), index(m_components.size() - 1), { ColRole, RowRole });
}

// The free spot of the same size that's closest to where the component is now
QRect WorkspaceModel::nearestFreeSpot(const QRect &component, const QList<QRect> &taken) const
{
    // Below the lowest component there's always room, so there's no need to look further down
    int bottom = 0;
    for (const QRect &other : taken)
        bottom = qMax(bottom, other.y() + other.height());

    QRect best;
    int bestDistance = INT_MAX;
    for (int row = 0; row <= bottom; ++row) {
        for (int col = 0; col + component.width() <= columns; ++col) {
            const QRect spot(col, row, component.width(), component.height());
            const bool free = std::none_of(taken.begin(), taken.end(),
                                           [&](const QRect &other) { return other.intersects(spot); });
            const int distance = qAbs(col - component.x()) + qAbs(row - component.y());
            if (free && distance < bestDistance) {
                best = spot;
                bestDistance = distance;
            }
        }
    }
    return best;
}