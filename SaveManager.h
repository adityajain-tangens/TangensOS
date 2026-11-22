#pragma once

#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QThreadPool>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class QJSEngine;
class QQmlEngine;
class WorkspaceModel;

// Saves the workspace as JSON in the app's own data folder, and loads it back when the app starts.
// There's one, shared by the whole app: SaveManager::instance() in C++, or SaveManager in QML.
// Once it's watching a WorkspaceModel, it saves a moment after anything in it changes, and before
// the app quits. Anything else that changes what should be saved can call saveLater() or save().
// Reading and writing the file happen on a background thread, so the UI never waits for the disk.
// Only that does: the model is only ever read and changed on the main thread.
class SaveManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Where the workspace is saved, like ~/Library/Application Support/appTangens/workspace.json
    Q_PROPERTY(QString path READ path CONSTANT)
    // False until the saved workspace has been read and put in the model
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)

public:
    static SaveManager *instance();
    // So QML gets the same one as C++
    static SaveManager *create(QQmlEngine *, QJSEngine *);

    // Fills this model from the saved workspace, if there is one, then saves it whenever it changes.
    // Called by the model itself as it's made. The model starts empty, and fills once the file has been
    // read in the background; until then, nothing is saved, so the file can't be overwritten with nothing.
    void watch(WorkspaceModel *model);

    // Writes the workspace to its file now
    Q_INVOKABLE void save();
    // Writes it a moment from now, so many changes in a row, like a drag, write the file only once
    Q_INVOKABLE void saveLater();

    QString path() const;
    bool loaded() const { return m_loaded; }

signals:
    void loadedChanged();

private:
    explicit SaveManager(QObject *parent = nullptr);

    QJsonObject toJson() const;
    void fromJson(const QJsonObject &json);
    static void writeFile(QJsonObject &json, const QString &file, const QVariant &scroll);
    static QVariant readScroll(const QJsonObject &json);

    // The workspace being saved
    QPointer<WorkspaceModel> m_model;
    bool m_loaded = false;
    QTimer m_saveTimer;
    // The background thread that reads and writes the file. Just one, so saves are written in order
    // and a newer one is never overwritten by an older one.
    QThreadPool m_disk;
};
