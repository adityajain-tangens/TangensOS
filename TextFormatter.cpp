#include "TextFormatter.h"

#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>
#include <QTextList>

using Marker = QTextBlockFormat::MarkerType;

// A cursor that covers the whole lines from start to end
static QTextCursor linesCursor(QQuickTextDocument *document, int start, int end)
{
    QTextCursor cursor(document->textDocument());
    cursor.setPosition(start);
    cursor.movePosition(QTextCursor::StartOfBlock);
    cursor.setPosition(end, QTextCursor::KeepAnchor);
    cursor.movePosition(QTextCursor::EndOfBlock, QTextCursor::KeepAnchor);
    return cursor;
}

void TextFormatter::toggleHeadline(QQuickTextDocument *document, int start, int end)
{
    QTextCursor cursor = linesCursor(document, start, end);
    const bool isHeadline = cursor.blockFormat().headingLevel() > 0;

    QTextBlockFormat line;
    line.setHeadingLevel(isHeadline ? 0 : 2);
    // A headline is bold and 1.6 times the normal size
    const qreal normalSize = document->textDocument()->defaultFont().pointSizeF();
    QTextCharFormat text;
    text.setFontWeight(isHeadline ? QFont::Normal : QFont::Bold);
    text.setFontPointSize(isHeadline ? normalSize : qRound(normalSize * 1.6));

    cursor.beginEditBlock();
    cursor.mergeBlockFormat(line);
    cursor.mergeCharFormat(text);
    // So text typed on an empty headline line looks like a headline too
    cursor.mergeBlockCharFormat(text);
    cursor.endEditBlock();
}

// Makes the lines into a list of this style, or back into plain lines if they already are one
static void toggleList(QTextCursor cursor, QTextListFormat::Style style, bool checkboxes)
{
    QTextList *list = cursor.currentList();
    const bool hadCheckboxes = cursor.blockFormat().marker() != Marker::NoMarker;
    const bool alreadyThis = list && list->format().style() == style && hadCheckboxes == checkboxes;

    QTextBlockFormat marker;
    marker.setMarker(checkboxes && !alreadyThis ? Marker::Unchecked : Marker::NoMarker);

    cursor.beginEditBlock();
    cursor.mergeBlockFormat(marker);
    if (alreadyThis) {
        const QTextDocument *document = cursor.document();
        QTextBlock block = document->findBlock(cursor.selectionStart());
        const QTextBlock last = document->findBlock(cursor.selectionEnd());
        while (block.isValid() && block.blockNumber() <= last.blockNumber()) {
            if (QTextList *itsList = block.textList())
                itsList->remove(block);
            block = block.next();
        }
    } else {
        cursor.createList(style);
    }
    cursor.endEditBlock();
}

void TextFormatter::toggleBullets(QQuickTextDocument *document, int start, int end)
{
    toggleList(linesCursor(document, start, end), QTextListFormat::ListDisc, false);
}

void TextFormatter::toggleNumbers(QQuickTextDocument *document, int start, int end)
{
    toggleList(linesCursor(document, start, end), QTextListFormat::ListDecimal, false);
}

void TextFormatter::toggleCheckboxes(QQuickTextDocument *document, int start, int end)
{
    toggleList(linesCursor(document, start, end), QTextListFormat::ListDisc, true);
}

void TextFormatter::flipCheckbox(QQuickTextDocument *document, int position)
{
    QTextCursor cursor(document->textDocument());
    cursor.setPosition(position);
    QTextBlockFormat line = cursor.blockFormat();
    if (line.marker() == Marker::NoMarker)
        return;
    line.setMarker(line.marker() == Marker::Checked ? Marker::Unchecked : Marker::Checked);
    cursor.setBlockFormat(line);
}
