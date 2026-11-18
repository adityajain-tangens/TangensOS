#pragma once

#include <QObject>
#include <QQuickTextDocument>
#include <QtQml/qqmlregistration.h>

// Line formatting for text fields: headlines, bullet and numbered lists, checkboxes.
// QML can't do these on its own. Bold, italics and underline are done in QML.
// Each one changes the lines from start to end, which are cursor positions in the text.
class TextFormatter : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    Q_INVOKABLE void toggleHeadline(QQuickTextDocument *document, int start, int end);
    Q_INVOKABLE void toggleBullets(QQuickTextDocument *document, int start, int end);
    Q_INVOKABLE void toggleNumbers(QQuickTextDocument *document, int start, int end);
    Q_INVOKABLE void toggleCheckboxes(QQuickTextDocument *document, int start, int end);

    // Ticks or unticks the checkbox on the line at this position, if it has one
    Q_INVOKABLE void flipCheckbox(QQuickTextDocument *document, int position);
};
