import Quickshell
import QtQuick

// A tray menu's entries, submenus included: an entry with children shows a chevron and
// a click opens them in a column to its right, the way menus cascade, with the parent
// staying put and its open entry highlighted and the child's top level with that entry.
// Each open column is its own panel: `panels` lists them, relative to `card`, for the
// host to hand up so the bar draws a blob for each; the first column is the card's.
// Separators, greyed-out entries and check marks as the app sends them. The host
// closes on `activated`. Sized by all its columns: the host reads implicitWidth.
Item {
    id: list

    // The menu at the top: the tray item's.
    property var menuHandle: null
    // Entries opened, one column each, outermost first.
    property var stack: []
    // A column is as wide as its longest label wants, within reason.
    property int minWidth: 150
    readonly property int maxWidth: 320
    readonly property int count: first.count
    // The card the panels are reported against, and what the first column takes of it.
    property Item card: null
    readonly property int margin: 6
    readonly property real baseWidth: first.width
    readonly property real baseHeight: first.height
    // Open columns as rects in the card's coordinates, each with the margin around it.
    property var panels: []

    signal activated

    function setPanel(depth, rect) {
        const next = panels.slice();
        next[depth - 1] = rect;
        panels = next.slice(0, stack.length);
    }

    // The columns drawn, by depth: the open ones, then any just folded, still fading out
    // while the card draws its blob back in. The model only grows and shrinks at its tail,
    // so the columns that stay open aren't rebuilt and don't replay their entrance.
    property var drawn: []

    onStackChanged: {
        panels = panels.slice(0, stack.length);
        let k = 0;
        while (k < stack.length && k < drawn.length && drawn[k] === stack[k])
            k++;
        if (k === stack.length) {
            // Folded back: the rest fade, and a reopened one comes back from its fade.
            for (let i = 0; i < drawn.length; i++)
                columnModel.setProperty(i, "folding", i >= k);
            if (drawn.length > k)
                fold.restart();
            return;
        }
        // Gone before the handles move, so no column on its way out opens another menu.
        for (let i = 0; i < k; i++)
            columnModel.setProperty(i, "folding", false);
        if (columnModel.count > k)
            columnModel.remove(k, columnModel.count - k);
        drawn = stack.slice();
        for (let i = k; i < stack.length; i++)
            columnModel.append({ folding: false });
    }

    // Done fading: the folded columns go.
    function drop() {
        if (columnModel.count > stack.length)
            columnModel.remove(stack.length, columnModel.count - stack.length);
        drawn = drawn.slice(0, stack.length);
    }

    // Sized by the open columns alone, so the card shrinks while a folded one fades. The
    // Repeater among the children has no `folding`.
    implicitWidth: {
        let w = first.width;
        for (const c of columns.children)
            if (c.folding === false)
                w = Math.max(w, c.x + c.width);
        return w;
    }
    implicitHeight: {
        let h = first.height;
        for (const c of columns.children)
            if (c.folding === false)
                h = Math.max(h, c.y + c.height);
        return h;
    }

    function reset() {
        stack = [];
        fold.stop();
        drop();
    }

    Timer {
        id: fold
        // The longer of the two fades, in case it was still coming in.
        interval: Motion.slowEffects
        onTriggered: list.drop()
    }

    ListModel {
        id: columnModel
    }

    component Level: Column {
        id: level

        property var handle: null
        property int depth: 0
        // The column this one opened from, for lining up with its open entry.
        property var above: null
        // Folded, fading out until it goes.
        property bool folding: false
        readonly property int count: opener.children.values.length
        // Where the open entry starts, from the entries before it: 32 a row, 9 a separator.
        readonly property real openY: {
            const open = list.stack.length > depth ? list.stack[depth] : null;
            let y = 0;
            for (const e of opener.children.values) {
                if (e === open)
                    return y;
                y += e.isSeparator ? 9 : 32;
            }
            return 0;
        }

        // Each entry reports its natural width; the widest sets the column's.
        property var natural: ({})
        function report(key, w) {
            natural = Object.assign({}, natural, { [key]: w });
        }

        width: Math.max(list.minWidth, Math.min(list.maxWidth, Math.max(0, ...Object.values(natural))))
        x: above ? above.x + above.width + 2 * list.margin : 0
        y: above ? above.y + above.openY : 0

        function place() {
            if (depth === 0 || folding || !list.card)
                return;
            const p = list.mapToItem(list.card, x, y);
            list.setPanel(depth, Qt.rect(p.x - list.margin, p.y - list.margin, width + 2 * list.margin, height + 2 * list.margin));
        }
        onXChanged: place()
        onYChanged: place()
        onWidthChanged: place()
        onHeightChanged: place()
        onFoldingChanged: place()
        Component.onCompleted: place()

        QsMenuOpener {
            id: opener
            menu: level.handle
        }

        Repeater {
            model: opener.children

            Item {
                id: entry

                required property var modelData
                required property int index
                readonly property bool open: list.stack.length > level.depth && list.stack[level.depth] === modelData
                readonly property bool available: modelData.enabled

                width: level.width
                height: modelData.isSeparator ? 9 : 32

                // Label plus the check slot and the chevron slot.
                TextMetrics {
                    id: metrics
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    text: entry.modelData.text
                    onWidthChanged: level.report(entry.modelData.text + "#" + index, width + 30 + 28)
                }
                Component.onCompleted: level.report(entry.modelData.text + "#" + index, metrics.width + 30 + 28)

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    height: 1
                    color: Theme.colors.outlineVariant
                    visible: entry.modelData.isSeparator
                }

                StateLayer {
                    hovered: entryHover.hovered && entry.available
                    active: entry.open
                    visible: !entry.modelData.isSeparator
                }

                Glyph {
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    name: "check"
                    size: 14
                    color: Theme.colors.primary
                    visible: entry.modelData.checkState === Qt.Checked
                }

                Text {
                    anchors.fill: parent
                    leftPadding: 30
                    rightPadding: 28
                    verticalAlignment: Text.AlignVCenter
                    text: entry.modelData.text
                    visible: !entry.modelData.isSeparator
                    color: entry.available ? Theme.colors.fg : Theme.colors.outline
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                Glyph {
                    anchors {
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    name: "caret-right"
                    size: 14
                    color: entry.open ? Theme.colors.primary : Theme.colors.fgVariant
                    visible: entry.modelData.hasChildren
                }

                HoverHandler {
                    id: entryHover
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !entry.modelData.isSeparator && entry.available && !level.folding
                    onClicked: {
                        if (entry.modelData.hasChildren) {
                            // Again on the open one folds it back.
                            list.stack = entry.open ? list.stack.slice(0, level.depth) : [...list.stack.slice(0, level.depth), entry.modelData];
                        } else {
                            list.activated();
                            entry.modelData.triggered();
                        }
                    }
                }
            }
        }
    }

    Item {
        id: columns

        Level {
            id: first
            handle: list.menuHandle
            depth: 0
        }

        Repeater {
            id: opened
            model: columnModel

            Level {
                id: column

                required property int index
                required property var model
                property bool up: false

                handle: list.drawn[index] ?? null
                depth: index + 1
                folding: model.folding
                above: index === 0 ? first : opened.itemAt(index - 1)
                // Grows out of the entry that opened it. Scale leaves x, y and size alone,
                // so the panel reported for it is the settled one from the start.
                transformOrigin: Item.TopLeft
                opacity: up && !folding ? 1 : 0
                Component.onCompleted: up = true

                Behavior on opacity {
                    Anim { effects: true; slow: !column.folding }
                }

                Anim on scale {
                    from: 0.8
                    to: 1
                }
            }
        }
    }
}
