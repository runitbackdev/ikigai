import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

// One tray item: click activates, right-click asks for its menu, middle-click is the
// secondary action, the wheel scrolls it.
BarButton {
    id: button

    required property var modelData
    readonly property SystemTrayItem item: modelData

    signal menuRequested(Item at)

    // The bar button's own mouse area is on top of everything here, so the clicks come
    // as its signals.
    onClicked: item.onlyMenu ? menuRequested(button) : item.activate()
    onRightClicked: menuRequested(button)
    onMiddleClicked: item.secondaryActivate()

    Image {
        anchors.centerIn: parent
        width: Theme.iconSize
        height: Theme.iconSize
        source: button.item.icon
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectFit
        opacity: button.item.status === Status.Passive ? 0.6 : 1
    }

    WheelHandler {
        onWheel: event => button.item.scroll(event.angleDelta.y > 0 ? -1 : 1, false)
    }
}
