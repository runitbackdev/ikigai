import Quickshell
import QtQuick

// The password window for a new secured network, in the polkit card's shape: the rail's
// popout has no keyboard focus, an Overlay layer with exclusive focus does. Opens while
// Network.asking names a network; Enter or Connect submits, a failure shows why and
// keeps the field, Escape or a click outside gives up.
Scope {
    id: scope

    readonly property bool open: Network.asking !== ""
    readonly property bool busy: Network.pending !== "" && Network.pending === Network.asking
    readonly property string status: busy ? "Connecting…" : Network.error

    // The window outlives the request by its fade, with the network's name and the last
    // status held so the card does not empty on the way out.
    property bool closing: false
    property string ssid: ""
    property var note: ({ text: "", busy: false })

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

    Binding {
        target: scope
        property: "ssid"
        value: Network.asking
        when: scope.open
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: scope
        property: "note"
        value: ({ text: scope.status, busy: scope.busy })
        when: scope.status !== ""
        restoreMode: Binding.RestoreNone
    }

    function close() {
        Network.asking = "";
    }

    Connections {
        target: Network

        function onSsidChanged() {
            if (Network.ssid !== "" && Network.ssid === Network.asking)
                scope.close();
        }
    }

    LazyLoader {
        active: scope.open || scope.closing

        DialogWindow {
            layerName: "wifi"
            closing: scope.closing
            onDismissed: scope.close()

            DialogCard {
                id: card

                readonly property int fieldWidth: Math.round(300 * Config.scale)

                anchors.centerIn: parent
                shown: !scope.closing

                function submit() {
                    if (scope.busy || password.text === "")
                        return;
                    Network.connect(Network.asking, password.text);
                }

                // Asked again inside the fade, the same window comes back: start it empty.
                Connections {
                    target: scope

                    function onOpenChanged() {
                        if (scope.open)
                            password.text = "";
                    }
                }

                Column {
                    id: column
                    spacing: Math.round(16 * Config.scale)

                    Column {
                        width: card.fieldWidth
                        spacing: 4

                        Text {
                            text: "Connect to " + scope.ssid
                            width: parent.width
                            color: Theme.colors.fg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize + 3
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "This network needs a password."
                            color: Theme.colors.fgVariant
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                        }
                    }

                    // The status carries its own gap, so it opens under the field and the
                    // buttons slide down rather than jump.
                    Column {
                        width: card.fieldWidth

                        Rectangle {
                            width: card.fieldWidth
                            height: Math.round(44 * Config.scale)
                            radius: Theme.radius
                            color: Theme.colors.surfaceContainerHigh
                            border.width: 1
                            border.color: password.activeFocus ? Theme.colors.primary : Theme.colors.outlineVariant
                            opacity: scope.busy ? 0.6 : 1

                            Behavior on border.color {
                                ColorAnim {}
                            }

                            TextInput {
                                id: password
                                anchors {
                                    left: parent.left
                                    right: reveal.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 14
                                }
                                echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                color: Theme.colors.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 1.1
                                focus: true
                                enabled: !scope.busy
                                clip: true
                                Keys.onReturnPressed: card.submit()
                                Keys.onEnterPressed: card.submit()
                                Component.onCompleted: forceActiveFocus()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Password"
                                    color: Theme.colors.outline
                                    font: password.font
                                    visible: password.text === ""
                                }
                            }

                            BarButton {
                                id: reveal
                                anchors {
                                    right: parent.right
                                    rightMargin: 6
                                    verticalCenter: parent.verticalCenter
                                }
                                onClicked: checked = !checked

                                Glyph {
                                    anchors.centerIn: parent
                                    name: reveal.checked ? "eye-slash" : "eye"
                                    size: 18
                                    color: Theme.colors.fgVariant
                                }
                            }
                        }

                        DialogReveal {
                            width: parent.width
                            gap: column.spacing
                            shown: scope.status !== ""

                            Text {
                                width: parent.width
                                text: scope.note.text
                                color: scope.note.busy ? Theme.colors.fgVariant : Theme.colors.error
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: Math.round(10 * Config.scale)

                        Pill {
                            label: "Cancel"
                            onClicked: scope.close()
                        }

                        Pill {
                            primary: true
                            label: "Connect"
                            enabled: !scope.busy && password.text !== ""
                            onClicked: card.submit()
                        }
                    }
                }
            }
        }
    }
}
