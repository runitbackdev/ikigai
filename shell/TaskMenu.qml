import Quickshell
import QtQuick

PopupCard {
    id: menu

    readonly property var entries: task ? build(task, Bridge.workspaces) : []
    // The app's tray menu, folded in below its own entries: for Discord that is mute,
    // deafen and quit, which have nowhere else to go now the tray icon is gone.
    readonly property var trayItem: task ? Tray.itemFor(task.appId) : null

    function build(task, workspaces) {
        const name = task.entry ? task.entry.name : task.appId;
        const list = [
            { label: name, run: () => task.entry && Apps.launch(task.entry) },
            { label: task.pinned ? "Unpin from taskbar" : "Pin to taskbar", run: () => task.pinned ? Config.unpin(task.appId) : Config.pin(task.appId) }
        ];
        const window = task.windows.find(w => w.states.includes("activated")) || task.windows[0];
        if (window) {
            for (const ws of workspaces.filter(ws => !window.workspaces.includes(ws.id)))
                list.push({ label: "Move to workspace " + ws.name, run: () => Bridge.moveToWorkspace(window.id, ws.id) });
            list.push({ label: task.windows.length > 1 ? "Close all windows" : "Close window", run: () => task.windows.forEach(w => Bridge.close(w.id)) });
        }
        return list;
    }

    implicitWidth: Math.max(menu.trayItem ? 240 : 220, trayEntries.implicitWidth + 12)
    implicitHeight: rows.implicitHeight + 12
    baseWidth: Math.max(menu.trayItem ? 240 : 220, trayEntries.baseWidth + 12)
    panels: trayEntries.panels

    // Back at the top every time the card comes up.
    onShownChanged: if (shown) trayEntries.reset()

    // One row, shared by our entries and the tray's: the tray's arrive with separators,
    // greyed-out items and check marks, and ours never do.
    component Entry: Item {
        id: entry

        property string label
        property bool separator: false
        property bool available: true
        property bool checked: false

        signal activated

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

        Text {
            anchors.fill: parent
            leftPadding: 12
            rightPadding: 30
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
            name: "check"
            size: 14
            color: Theme.colors.primary
            visible: entry.checked
        }

        HoverHandler {
            id: entryHover
        }

        MouseArea {
            anchors.fill: parent
            enabled: !entry.separator && entry.available
            onClicked: {
                menu.done();
                entry.activated();
            }
        }
    }

    Column {
        id: rows
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        Repeater {
            model: menu.entries

            Entry {
                required property var modelData

                width: rows.width
                label: modelData.label
                onActivated: modelData.run()
            }
        }

        Entry {
            width: rows.width
            separator: true
            visible: trayEntries.count > 0
        }

        TrayEntries {
            id: trayEntries
            // The first column spans the card like the app's own rows above it.
            minWidth: (menu.trayItem ? 240 : 220) - 12
            card: menu
            menuHandle: menu.trayItem ? menu.trayItem.menu : null
            onActivated: menu.done()
        }
    }
}
