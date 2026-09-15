import Quickshell
import QtQuick

// A tray menu's entries, submenus included: an entry with children shows a chevron and
// opens in place, with a row at the top to go back up. Separators, greyed-out entries
// and check marks as the app sends them. The host closes on `activated`.
Column {
    id: list

    // The menu at the top: the tray item's.
    property var menuHandle: null
    // Entries descended into, innermost last.
    property var stack: []
    readonly property bool nested: stack.length > 0
    readonly property int count: opener.children.values.length

    signal activated

    function push(entry) {
        stack = [...stack, entry];
    }

    function pop() {
        stack = stack.slice(0, -1);
    }

    function reset() {
        stack = [];
    }

    QsMenuOpener {
        id: opener
        menu: list.stack.length > 0 ? list.stack[list.stack.length - 1] : list.menuHandle
    }

    component Entry: Item {
        id: entry

        property string label
        property bool separator: false
        property bool available: true
        property bool checked: false
        property bool submenu: false
        property bool back: false

        signal activated

        width: list.width
        height: separator ? 9 : 32

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 24
            height: 1
            color: Theme.colors.outlineVariant
            visible: entry.separator
        }

        StateLayer {
            hovered: entryHover.hovered && entry.available
            visible: !entry.separator
        }

        Glyph {
            anchors {
                left: parent.left
                leftMargin: 10
                verticalCenter: parent.verticalCenter
            }
            name: entry.back ? "caret-left" : "check"
            size: 14
            color: entry.back ? Theme.colors.fg : Theme.colors.primary
            visible: entry.back || entry.checked
        }

        Text {
            anchors.fill: parent
            leftPadding: 30
            rightPadding: 28
            verticalAlignment: Text.AlignVCenter
            text: entry.label
            visible: !entry.separator
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
            color: Theme.colors.fgVariant
            visible: entry.submenu
        }

        HoverHandler {
            id: entryHover
        }

        MouseArea {
            anchors.fill: parent
            enabled: !entry.separator && entry.available
            onClicked: entry.activated()
        }
    }

    Entry {
        visible: list.nested
        back: true
        label: list.nested ? list.stack[list.stack.length - 1].text : ""
        onActivated: list.pop()
    }

    Entry {
        visible: list.nested
        separator: true
    }

    Repeater {
        model: opener.children

        Entry {
            required property var modelData

            label: modelData.text
            separator: modelData.isSeparator
            available: modelData.enabled
            checked: modelData.checkState === Qt.Checked
            submenu: modelData.hasChildren
            onActivated: {
                if (modelData.hasChildren) {
                    list.push(modelData);
                } else {
                    list.activated();
                    modelData.triggered();
                }
            }
        }
    }
}
