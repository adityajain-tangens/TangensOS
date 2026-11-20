#include "WorkspaceModel.h"

#include <algorithm>
#include <limits>

WorkspaceModel::WorkspaceModel(QObject *parent)
    : QAbstractListModel(parent)
{
    // The starting components: x, y, width, height
    m_components = {
        QRect(0, 0, 366, 366),
        QRect(378, 0, 177, 156),
        QRect(567, 0, 177, 156),
        QRect(378, 168, 366, 198),
        QRect(0, 378, 240, 240),
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
    switch (role) {
    case AreaRole: return m_components.at(index.row());
    case ItemRole: return m_items.at(index.row());
    case FileRole: return m_files.at(index.row());
    case TextRole: return m_texts.at(index.row());
    }
    return {};
}

// The names QML uses for each value
QHash<int, QByteArray> WorkspaceModel::roleNames() const
{
    return { { AreaRole, "area" }, { ItemRole, "item" }, { FileRole, "file" }, { TextRole, "text" } };
}

bool WorkspaceModel::addComponent(const QString &item, const QString &file, int x, int y, const QString &text)
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
