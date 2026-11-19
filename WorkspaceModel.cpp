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
    m_items = { "TextFieldItem", "", "", "WebViewItem", "" };
    // None of them shows a file to start with
    m_files = QList<QString>(m_components.size());
    m_texts = QList<QString>(m_components.size());
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
    case FileRole: return m_files.at(index.row());
    case TextRole: return m_texts.at(index.row());
    }
    return {};
}

// The names QML uses for each value
QHash<int, QByteArray> WorkspaceModel::roleNames() const
{
    return { { ColRole, "col" }, { RowRole, "row" }, { ColsRole, "cols" }, { RowsRole, "rows" },
             { ItemRole, "item" }, { FileRole, "file" }, { TextRole, "text" } };
}

bool WorkspaceModel::addComponent(const QString &item, const QString &file, int col, int row, int cols, int rows,
                                  const QString &text)
{
    const QPoint cell(col, row);
    for (const QRect &other : m_components) {
        if (other.contains(cell))
            return false;
    }

    QRect component(col, row, cols, rows);
    component = nearestFreeSpot(component, m_components);

    const int at = m_components.size();
    beginInsertRows({}, at, at);
    m_components.append(component);
    m_atStart.append(component);
    m_items.append(item);
    m_files.append(file);
    m_texts.append(text);
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

void WorkspaceModel::removeComponent(int component)
{
    beginRemoveRows({}, component, component);
    m_components.removeAt(component);
    m_items.removeAt(component);
    m_files.removeAt(component);
    m_texts.removeAt(component);
    endRemoveRows();
    emit boundsChanged();
}

void WorkspaceModel::startChange()
{
    m_atStart = m_components;
}

// Moves a component to a new cell, keeping its size
void WorkspaceModel::moveComponent(int component, int col, int row)
{
    QRect moved = m_atStart.at(component);
    moved.moveTo(col, row);
    place(component, moved);
}

// Resizes a component by moving its edges. Edges are grid lines: a component at column 6
// that's 3 columns wide runs from line 6 to line 9. Only the edges that moved are changed.
void WorkspaceModel::resizeComponent(int component, int left, int top, int right, int bottom)
{
    const QRect start = m_atStart.at(component);
    const int startRight = start.x() + start.width();
    const int startBottom = start.y() + start.height();

    // Keep each edge that moved at least the minimum size from the opposite edge
    if (left != start.x())
        left = qMin(left, startRight - minCols);
    if (right != startRight)
        right = qMax(start.x() + minCols, right);
    if (top != start.y())
        top = qMin(top, startBottom - minRows);
    if (bottom != startBottom)
        bottom = qMax(start.y() + minRows, bottom);

    place(component, QRect(left, top, right - left, bottom - top));
}

// Puts one component at a new rectangle of cells. Any component it now covers moves to the
// nearest free spot. Always works from where things were when the change started, so a pushed
// component goes back if the changed one moves away again.
void WorkspaceModel::place(int component, const QRect &moved)
{
    // First everything that stays: the changed component, and every component it doesn't cover
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
    emit dataChanged(index(0), index(m_components.size() - 1), { ColRole, RowRole, ColsRole, RowsRole });
    emit boundsChanged();
}

// The smallest rectangle of cells holding every component
QRect WorkspaceModel::bounds() const
{
    QRect all;
    for (const QRect &component : m_components)
        all |= component;
    return all;
}

// The free spot of the same size that's closest to where the component is now
QRect WorkspaceModel::nearestFreeSpot(const QRect &component, const QList<QRect> &taken) const
{
    // Past the outermost components there's always room, so there's no need to look further out
    int left = component.x();
    int top = component.y();
    int right = component.x();
    int bottom = component.y();
    for (const QRect &other : taken) {
        left = qMin(left, other.x() - component.width());
        top = qMin(top, other.y() - component.height());
        right = qMax(right, other.x() + other.width());
        bottom = qMax(bottom, other.y() + other.height());
    }

    QRect best;
    int bestDistance = INT_MAX;
    for (int row = top; row <= bottom; ++row) {
        for (int col = left; col <= right; ++col) {
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