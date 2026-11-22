#pragma once

#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class QJSEngine;
class QQmlEngine;
class WorkspaceModel;

// Saves the workspace as JSON in the app's own data folder, and loads it back when the app starts.
// There's one, shared by the whole app: SaveManager::instance() in C++, or SaveManager in QML.
// Once it's watching a WorkspaceModel, it saves a moment after anything in it changes, and before
// the app quits. Anything else that changes what should be saved can call saveLater() or save().
class SaveManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Where the workspace is saved, like ~/Library/Application Support/appTangens/workspace.json
    Q_PROPERTY(QString path READ path CONSTANT)

public:
    static SaveManager *instance();
    // So QML gets the same one as C++
    static SaveManager *create(QQmlEngine *, QJSEngine *);

    // Fills this model from the saved workspace, if there is one, then saves it whenever it changes.
    // Called by the model itself as it's made, before anything shows it.
    void watch(WorkspaceModel *model);

    // Writes the workspace to its file now
    Q_INVOKABLE void save();
    // Writes it a moment from now, so many changes in a row, like a drag, write the file only once
    Q_INVOKABLE void saveLater();

    QString path() const;

private:
    explicit SaveManager(QObject *parent = nullptr);

    QJsonObject toJson() const;
    void fromJson(const QJsonObject &json);
    static void writeFile(QJsonObject &json, const QString &file, const QVariant &scroll);
    static QVariant readScroll(const QJsonObject &json);

    // The workspace being saved
    QPointer<WorkspaceModel> m_model;
    QTimer m_saveTimer;
};
