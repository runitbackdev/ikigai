import QtQuick

// A tray item's menu: its entries, submenus opening in place.
PopupCard {
    id: menu

    // `task` carries the tray item, as Popouts hands it over.
    readonly property var item: task

    implicitWidth: 240
    implicitHeight: entries.implicitHeight + 12

    // Back at the top every time the card comes up.
    onShownChanged: if (shown) entries.reset()

    TrayEntries {
        id: entries
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        menuHandle: menu.item ? menu.item.menu : null
        onActivated: menu.done()
    }
}
