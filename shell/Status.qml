import QtQuick

// Status items above the clock: the tray icons no rail button already owns, an arrow
// while an update is waiting, the microphone while something captures, the cup for
// keeping the screen on, the network, Bluetooth when there is an adapter, the battery
// when there is one, then the output volume (scroll to adjust, click for the card).
Column {
    id: status

    readonly property alias networkButton: network
    property bool networkOpen: false
    property bool bluetoothOpen: false
    property bool batteryOpen: false
    property bool volumeOpen: false
    property bool caffeineOpen: false

    signal networkRequested(Item at)
    signal bluetoothRequested(Item at)
    signal batteryRequested(Item at)
    signal volumeRequested(Item at)
    signal caffeineRequested(Item at)
    signal trayMenuRequested(var item, Item at)

    spacing: 4

    Repeater {
        model: Tray.loose

        TrayButton {
            onMenuRequested: at => status.trayMenuRequested(item, at)
        }
    }

    BarButton {
        id: updates
        visible: Updates.available
        onClicked: Updates.run()

        Glyph {
            anchors.centerIn: parent
            name: "arrow-circle-up"
            size: Theme.iconSize
            color: Theme.colors.primary
        }
    }

    BarButton {
        id: mic
        visible: Audio.recording
        onClicked: Audio.toggleMicMute()

        Glyph {
            anchors.centerIn: parent
            name: Audio.micMuted ? "microphone-slash" : "microphone"
            size: Theme.iconSize
            fill: !Audio.micMuted
            color: Audio.micMuted ? Theme.colors.fgVariant : Theme.colors.error
        }
    }

    BarButton {
        id: caffeine
        checked: status.caffeineOpen
        onClicked: Caffeine.toggle()
        onRightClicked: status.caffeineRequested(caffeine)

        Glyph {
            anchors.centerIn: parent
            name: "coffee"
            size: Theme.iconSize
            fill: Caffeine.active
            color: Caffeine.active ? Theme.colors.fg : Theme.colors.fgVariant
        }
    }

    BarButton {
        id: network
        checked: status.networkOpen
        onClicked: status.networkRequested(network)

        Glyph {
            anchors.centerIn: parent
            name: Network.icon
            size: Theme.iconSize
            color: Network.connected ? Theme.colors.fg : Theme.colors.fgVariant
        }
    }

    BarButton {
        id: bluetooth
        visible: Bluetooth.present
        checked: status.bluetoothOpen
        onClicked: status.bluetoothRequested(bluetooth)

        Glyph {
            anchors.centerIn: parent
            name: Bluetooth.icon
            size: Theme.iconSize
            color: Bluetooth.connectedCount > 0 ? Theme.colors.fg : Theme.colors.fgVariant
        }
    }

    BarButton {
        id: battery
        visible: Power.present
        checked: status.batteryOpen
        onClicked: status.batteryRequested(battery)

        Glyph {
            anchors.centerIn: parent
            name: Power.icon
            size: Theme.iconSize
            color: Power.low ? Theme.colors.error : Theme.colors.fg
        }
    }

    BarButton {
        id: volume
        checked: status.volumeOpen
        onClicked: status.volumeRequested(volume)

        Glyph {
            anchors.centerIn: parent
            name: Audio.icon
            size: Theme.iconSize
            color: Audio.muted ? Theme.colors.fgVariant : Theme.colors.fg
        }

        WheelHandler {
            onWheel: event => Audio.step(event.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }
}
