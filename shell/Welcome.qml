import Quickshell
import Quickshell.Io
import QtQuick

// The first-login card: keys, the rail, where settings live. Shown once per user, a
// moment after the shell starts, while ~/.local/state/ikigai/welcomed is missing; closing
// writes it. `ikigai-shell welcome open` brings it back. A box with no connectivity gets
// a button that opens the rail's network card.
Scope {
    id: scope

    property bool open: false
    property bool online: true
    // The window outlives `open` by its fade.
    property bool closing: false

    readonly property var keys: [
        ["Super", "Vicinae: apps, files, clipboard; type log out or power off"],
        ["Super+W", "task view: workspaces and their windows"],
        ["Alt+Tab", "window switcher, hold and cycle"],
        ["Super+Return", "terminal"],
        ["Super+Escape", "lock"],
        ["Print", "screenshot picker"],
        ["Super+Shift+/", "every binding"],
    ]

    function close() {
        open = false;
        marker.setText(new Date().toISOString() + "\n");
    }

    function wifi() {
        close();
        Network.cardRequested();
    }

    onOpenChanged: {
        closing = !open;
        if (closing)
            fade.restart();
        else
            fade.stop();
    }

    Timer {
        id: fade
        interval: Motion.defaultEffects
        onTriggered: scope.closing = false
    }

    IpcHandler {
        target: "welcome"

        function open(): void {
            scope.open = true;
        }
    }

    FileView {
        id: marker
        path: Theme.stateDir + "/welcomed"
        printErrors: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                delay.start();
        }
    }

    // Let the wallpaper and the rail land first.
    Timer {
        id: delay
        interval: 1500
        onTriggered: scope.open = true
    }

    Process {
        command: ["nmcli", "-g", "CONNECTIVITY", "general"]
        running: scope.open
        stdout: StdioCollector {
            onStreamFinished: scope.online = text.trim() === "full"
        }
    }

    component Section: Row {
        id: section

        property string icon
        property string title
        default property alias body: bodySlot.data

        width: parent.width
        spacing: Math.round(14 * Config.scale)

        Glyph {
            name: section.icon
            size: Math.round(22 * Config.scale)
            color: Theme.colors.primary
        }

        Column {
            id: bodySlot
            width: parent.width - parent.spacing - Math.round(22 * Config.scale)
            spacing: Math.round(6 * Config.scale)

            Text {
                text: section.title
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 1
                font.weight: Font.Medium
            }
        }
    }

    component Body: Text {
        width: parent.width
        color: Theme.colors.fgVariant
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        wrapMode: Text.Wrap
    }

    LazyLoader {
        active: scope.open || scope.closing

        DialogWindow {
            layerName: "welcome"
            closing: scope.closing
            onDismissed: scope.close()

            DialogCard {
                anchors.centerIn: parent
                pad: Math.round(32 * Config.scale)
                shown: !scope.closing

                Column {
                    id: column
                    width: Math.round(520 * Config.scale)
                    spacing: Math.round(22 * Config.scale)

                    Column {
                        width: parent.width
                        spacing: Math.round(4 * Config.scale)

                        Text {
                            text: "Welcome to Ikigai"
                            color: Theme.colors.fg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize * 1.8
                            font.weight: Font.Medium
                        }

                        Body {
                            text: "Three things worth knowing. The rest is in the cheatsheet."
                        }
                    }

                    Section {
                        icon: "keyboard"
                        title: "Keys"

                        Column {
                            width: parent.width
                            spacing: Math.round(4 * Config.scale)

                            Repeater {
                                model: scope.keys

                                Row {
                                    required property var modelData

                                    readonly property int chordWidth: Math.round(120 * Config.scale)

                                    width: parent.width
                                    spacing: Math.round(12 * Config.scale)

                                    Text {
                                        width: parent.chordWidth
                                        text: parent.modelData[0]
                                        color: Theme.colors.primary
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSize
                                        font.weight: Font.Medium
                                    }

                                    Body {
                                        width: parent.width - parent.chordWidth - parent.spacing
                                        text: parent.modelData[1]
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        icon: "sidebar-simple"
                        title: "The rail"

                        Body {
                            text: "Hover the left edge. Pinned apps at the top, right-click one to pin or unpin. Below them the tray, the volume and the clock, which opens notifications and the calendar."
                        }
                    }

                    Section {
                        icon: "gear"
                        title: "Settings"

                        Body {
                            text: "Type Settings into Vicinae for displays, wallpaper, keyboard and users. The rail's own options are in ~/.config/ikigai/shell.json."
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: Math.round(10 * Config.scale)

                        Pill {
                            visible: !scope.online
                            label: "Connect to Wi-Fi"
                            onClicked: scope.wifi()
                        }

                        Pill {
                            primary: true
                            label: "Got it"
                            onClicked: scope.close()
                        }
                    }
                }
            }
        }
    }
}
