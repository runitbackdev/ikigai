import QtQuick

// A tray item's menu: its entries, submenus cascading to the right.
PopupCard {
    id: menu

    // `task` carries the tray item, as Popouts hands it over.
    readonly property var item: task

    implicitWidth: entries.implicitWidth + 12
    implicitHeight: entries.implicitHeight + 12
    baseWidth: entries.baseWidth + 12
    baseHeight: entries.baseHeight + 12
    panels: entries.panels

    // Back at the top every time the card comes up.
    onShownChanged: if (shown) entries.reset()

    TrayEntries {
        id: entries
        anchors {
            left: parent.left
            top: parent.top
        }
        card: menu
        menuHandle: menu.item ? menu.item.menu : null
        onActivated: menu.done()
    }
}
