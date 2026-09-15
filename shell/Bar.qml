import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import Ikigai.Blobs

// One full-screen layer per screen: the frame around the desktop, the rail sunk into its
// left border, and any open card, all drawn as blobs of a single group so they melt
// together. Reserved space comes from Exclusions.
PanelWindow {
    id: bar

    property bool shown: true
    // Toasts belong to one screen, not to every rail.
    readonly property bool showsToasts: bar.screen === Notifs.screen
    // Hovering the toasts is not a request for the rail; an open sidebar keeps it out.
    readonly property bool wanted: !Config.autohide || sidebar.open || (hover.hovered && !toasts.hovered)
    property real reveal: shown ? 1 : 0
    // The left border thickens into the rail as it reveals.
    readonly property real railWidth: Theme.border + (Theme.barWidth - Theme.border) * reveal

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "ikigai:bar"
    color: "transparent"

    // Input only on the rail (the bare border while hidden), the open card and the toasts;
    // the whole screen while the sidebar is open, so a click anywhere else closes it.
    mask: Region {
        x: 0
        y: 0
        width: sidebar.open ? bar.width : bar.railWidth
        height: bar.height

        regions: [
            Region {
                x: bar.railWidth
                y: popouts.card ? popouts.card.y : 0
                width: popouts.card ? popouts.card.width : 0
                height: popouts.card ? popouts.card.height : 0
            },
            Region {
                x: toasts.x
                y: toasts.y
                width: toasts.width
                height: toasts.height
            }
        ]
    }

    Behavior on reveal {
        Anim { standard: true }
    }

    // Reveal at once; hide after a grace period so grazing the edge doesn't flicker.
    Component.onCompleted: shown = wanted
    onWantedChanged: {
        if (wanted)
            shown = true;
        else
            hideTimer.restart();
    }
    onShownChanged: if (!shown) popouts.close()

    // The welcome card's Wi-Fi button: the network card on the rail, revealed like Super+W.
    Connections {
        target: Network
        function onCardRequested() {
            bar.shown = true;
            popouts.toggleNetwork(status.networkButton);
        }
    }

    // Super+W: the card opens on a hidden rail too, and the rail stays until the card goes.
    Connections {
        target: Tasks
        function onTaskViewToggled() {
            if (popouts.workspacesOpen) {
                popouts.close();
                bar.shown = bar.wanted;
            } else {
                bar.shown = true;
                popouts.toggleWorkspaces(taskbar.taskView);
            }
        }
    }

    Binding {
        target: Osd
        property: "suppressed"
        value: popouts.volumeOpen
    }

    Timer {
        id: hideTimer
        interval: Motion.grace
        onTriggered: bar.shown = bar.wanted
    }

    Exclusions {
        screen: bar.screen
        left: Config.autohide ? Theme.border : Theme.barWidth
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: hover
        }

        MouseArea {
            anchors.fill: parent
            enabled: sidebar.open
            onClicked: Notifs.sidebarScreen = null
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha("black", 0.6)
            }

            BlobGroup {
                id: blobs
                color: Theme.colors.surface
                smoothing: Theme.smoothing
            }

            // Oversized by 50 so a closed card's bulge stays hidden in the border.
            BlobInvertedRect {
                anchors.fill: parent
                anchors.margins: -50
                group: blobs
                radius: Theme.rounding
                borderLeft: bar.railWidth + 50
                borderRight: Theme.border + 50
                borderTop: Theme.border + 50
                borderBottom: Theme.border + 50
            }

            BlobRect {
                group: blobs
                x: popouts.x + (popouts.card ? 0 : -50)
                y: popouts.card ? popouts.card.y : 0
                implicitWidth: popouts.card ? popouts.card.width : 0
                implicitHeight: popouts.card ? popouts.card.height : 0
                radius: Theme.cardRadius
                deformScale: 0.15 / 10000
            }

            // The toast sheet, oversized upward so it hangs out of the top border.
            BlobRect {
                group: blobs
                x: toasts.x
                y: toasts.y - 50
                implicitWidth: toasts.width
                implicitHeight: toasts.visible && toasts.height > 0 ? toasts.height + 50 : 0
                radius: Theme.cardRadius
                deformScale: 0.15 / 10000

                Behavior on implicitHeight {
                    Anim {}
                }
            }

            // The OSD, oversized downward into the border, its bottom edge pinned.
            BlobRect {
                group: blobs
                x: osd.x
                y: osd.y + osd.height + 50 - implicitHeight
                implicitWidth: osd.width
                implicitHeight: Osd.shown ? osd.height + 50 : 0
                radius: Theme.cardRadius
                deformScale: 0.15 / 10000

                Behavior on implicitHeight {
                    Anim {}
                }
            }

            // The sidebar, oversized rightward into the border, its right edge pinned.
            BlobRect {
                group: blobs
                x: sidebar.x + sidebar.width + 50 - implicitWidth
                y: sidebar.y
                implicitWidth: sidebar.open ? sidebar.width + 50 : 0
                implicitHeight: sidebar.height
                radius: Theme.cardRadius
                deformScale: 0.15 / 10000

                Behavior on implicitWidth {
                    Anim {}
                }
            }
        }

        Toasts {
            id: toasts
            active: bar.showsToasts
            visible: !sidebar.open
            anchors {
                top: parent.top
                right: parent.right
                topMargin: Theme.border
                rightMargin: Theme.border + 8
            }
        }

        Item {
            id: rail
            x: bar.railWidth - Theme.barWidth
            width: Theme.barWidth
            height: parent.height
            opacity: bar.reveal

            Taskbar {
                id: taskbar
                anchors {
                    top: parent.top
                    topMargin: Theme.border
                    horizontalCenter: parent.horizontalCenter
                }
                screen: bar.screen
                workspacesOpen: popouts.workspacesOpen
                onMenuRequested: (task, at) => popouts.openMenu(task, at)
                onWindowsRequested: (task, at) => popouts.openWindows(task, at)
                onWorkspacesRequested: at => popouts.toggleWorkspaces(at)
                onDismissRequested: popouts.close()
            }

            TaskGroup {
                anchors {
                    bottom: status.top
                    bottomMargin: 8
                    horizontalCenter: parent.horizontalCenter
                }
                tasks: Tasks.onScreen(Tasks.bottom, bar.screen)
                onMenuRequested: (task, at) => popouts.openMenu(task, at)
                onWindowsRequested: (task, at) => popouts.openWindows(task, at)
                onDismissRequested: popouts.close()
            }

            Status {
                id: status
                anchors {
                    bottom: recording.top
                    bottomMargin: 8
                    horizontalCenter: parent.horizontalCenter
                }
                networkOpen: popouts.networkOpen
                bluetoothOpen: popouts.bluetoothOpen
                batteryOpen: popouts.batteryOpen
                volumeOpen: popouts.volumeOpen
                caffeineOpen: popouts.caffeineOpen
                onNetworkRequested: at => popouts.toggleNetwork(at)
                onBluetoothRequested: at => popouts.toggleBluetooth(at)
                onBatteryRequested: at => popouts.toggleBattery(at)
                onVolumeRequested: at => popouts.toggleVolume(at)
                onCaffeineRequested: at => popouts.toggleCaffeine(at)
                onTrayMenuRequested: (item, at) => popouts.openTray(item, at)
            }

            RecordingBadge {
                id: recording
                anchors {
                    bottom: clock.top
                    bottomMargin: Recorder.recording ? 8 : 0
                    horizontalCenter: parent.horizontalCenter
                }
            }

            Clock {
                id: clock
                screen: bar.screen
                anchors {
                    bottom: parent.bottom
                    bottomMargin: Theme.border + 4
                    horizontalCenter: parent.horizontalCenter
                }
            }
        }

        Popouts {
            id: popouts
            screen: bar.screen
            x: bar.railWidth
            height: parent.height
            hovered: hover.hovered
        }

        OsdPill {
            id: osd
            anchors {
                bottom: parent.bottom
                bottomMargin: Theme.border
                horizontalCenter: parent.horizontalCenter
            }
        }

        Sidebar {
            id: sidebar
            active: Notifs.sidebarScreen === bar.screen
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                margins: Theme.border
            }
        }
    }
}
