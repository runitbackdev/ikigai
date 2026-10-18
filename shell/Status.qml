import Quickshell
import QtQuick

// Status items above the clock: the tray icons no rail button already owns, an arrow
// while an update is waiting, the microphone while something captures, the cup for
// keeping the screen on, the network, Bluetooth when there is an adapter, the battery
// when there is one, then the output volume (scroll to adjust, click for the card).
Item {
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

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    // The column hangs from its bottom edge, so it grows upward: the height eases on the
    // move's curve, and the items below a change climb in y exactly as the top rises,
    // which keeps them still on screen. Same as TaskGroup.
    Behavior on implicitHeight {
        enabled: status.implicitHeight > 0
        Anim {}
    }

    Column {
        id: column
        spacing: 4

        // Positioners run these for children that turn visible too, so the update arrow,
        // the mic, Bluetooth and the battery grow in like a new tray icon.
        add: Transition {
            Anim { property: "grow"; from: 0; to: 1 }
        }

        move: Transition {
            Anim { property: "y" }
            Anim { property: "grow"; to: 1 }
        }

        // Diffed, so a tray change keeps the other icons instead of recreating them all.
        Repeater {
            model: ScriptModel {
                values: Tray.loose
            }

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

            // Red while live, brighter and a touch larger as you speak, grey when off. The
            // level arrives twenty times a second, so it is stepped (fewer colour retargets)
            // and the scale eases without overshoot: a spring restarted every sample buzzes.
            // The tint takes the scale's timing, not the slow colour fade, to keep up.
            Glyph {
                readonly property real level: Math.round(Audio.level * 10) / 10

                anchors.centerIn: parent
                name: Audio.micMuted ? "microphone-slash" : "microphone"
                size: Theme.iconSize
                fill: !Audio.micMuted
                animate: true
                quickTint: true
                color: Audio.micMuted ? Theme.colors.fgVariant : Qt.lighter(Theme.colors.error, 1 + level * 0.6)
                scale: Audio.micMuted ? 1 : 1 + level * 0.2

                Behavior on scale {
                    Anim { effects: true }
                }
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
                animate: true
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
                animate: true
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
                animate: true
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
                animate: true
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
                animate: true
                color: Audio.muted ? Theme.colors.fgVariant : Theme.colors.fg
            }

            WheelHandler {
                onWheel: event => Audio.step(event.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }
    }
}
