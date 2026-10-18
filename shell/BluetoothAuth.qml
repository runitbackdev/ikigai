import Quickshell
import QtQuick

// The pairing prompt, in the Wi-Fi password window's shape: a number to confirm, a code
// to type on the device, a PIN or passkey to type here, or a yes/no for a device that
// wants in. Opens while Bluetooth.request is set; Enter answers where there is a field,
// Escape or a click outside refuses.
Scope {
    id: scope

    readonly property var request: Bluetooth.request
    readonly property bool open: request !== null

    // The window outlives the request by its fade, with the request held so the card
    // does not empty on the way out; `request` stays the live one that answers go to.
    property bool closing: false
    property var held: null

    readonly property bool typing: held && (held.kind === "pin" || held.kind === "passkey")
    readonly property string title: !held ? "" : held.kind === "display" ? "Pair " + held.name
        : held.kind === "confirm" ? "Pair " + held.name
        : held.kind === "authorize" ? held.name + " wants to connect"
        : held.kind === "service" ? held.name + " wants to use a service" : "Pair " + held.name
    readonly property string detail: !held ? "" : held.kind === "display" ? "Type this on the device, then Enter there."
        : held.kind === "confirm" ? "Confirm the number shows on the device too."
        : held.kind === "pin" ? "The device wants a PIN."
        : held.kind === "passkey" ? "The device wants a six-digit passkey."
        : held.kind === "service" ? held.uuid : "Allow it?"

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
        property: "held"
        value: scope.request
        when: scope.open
        restoreMode: Binding.RestoreNone
    }

    function refuse() {
        Bluetooth.answer(false);
    }

    LazyLoader {
        active: scope.open || scope.closing

        DialogWindow {
            layerName: "bluetooth"
            closing: scope.closing
            onDismissed: scope.refuse()
            onAccepted: card.submit()

            DialogCard {
                id: card

                readonly property int fieldWidth: Math.round(300 * Config.scale)

                anchors.centerIn: parent
                shown: !scope.closing

                function submit() {
                    if (!scope.request || scope.request.kind === "display")
                        return;
                    if (scope.typing) {
                        if (field.text !== "")
                            Bluetooth.answer(true, field.text);
                    } else {
                        Bluetooth.answer(true);
                    }
                }

                // Asked again inside the fade, the same window comes back: start it empty.
                Connections {
                    target: scope

                    function onOpenChanged() {
                        if (scope.open)
                            field.text = "";
                    }
                }

                Column {
                    id: column
                    spacing: Math.round(16 * Config.scale)

                    Column {
                        width: card.fieldWidth
                        spacing: 4

                        Text {
                            text: scope.title
                            width: parent.width
                            color: Theme.colors.fg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize + 3
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            text: scope.detail
                            width: parent.width
                            wrapMode: Text.Wrap
                            color: Theme.colors.fgVariant
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                        }
                    }

                    // The number, big, with the digits already typed on the device lit.
                    Row {
                        visible: scope.held && (scope.held.kind === "confirm" || scope.held.kind === "display")
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Repeater {
                            model: scope.held && scope.held.passkey ? scope.held.passkey.split("") : []

                            Text {
                                required property string modelData
                                required property int index
                                text: modelData
                                color: scope.held && scope.held.kind === "display" && index >= (scope.held.entered || 0) ? Theme.colors.fgVariant : Theme.colors.fg
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize * 2.2
                                font.weight: Font.Medium
                            }
                        }
                    }

                    Rectangle {
                        visible: scope.typing
                        width: card.fieldWidth
                        height: Math.round(44 * Config.scale)
                        radius: Theme.radius
                        color: Theme.colors.surfaceContainerHigh
                        border.width: 1
                        border.color: field.activeFocus ? Theme.colors.primary : Theme.colors.outlineVariant

                        TextInput {
                            id: field
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 14
                                rightMargin: 14
                            }
                            color: Theme.colors.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 1.1
                            inputMethodHints: scope.held && scope.held.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
                            validator: RegularExpressionValidator {
                                regularExpression: scope.held && scope.held.kind === "passkey" ? /[0-9]{0,6}/ : /.{0,16}/
                            }
                            clip: true
                            Component.onCompleted: if (scope.typing) forceActiveFocus()

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: scope.held && scope.held.kind === "passkey" ? "Passkey" : "PIN"
                                color: Theme.colors.outline
                                font: field.font
                                visible: field.text === ""
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: Math.round(10 * Config.scale)

                        Pill {
                            label: "Cancel"
                            onClicked: scope.refuse()
                        }

                        Pill {
                            primary: true
                            visible: scope.held && scope.held.kind !== "display"
                            label: scope.held && (scope.held.kind === "authorize" || scope.held.kind === "service") ? "Allow" : scope.held && scope.held.kind === "confirm" ? "Matches" : "Pair"
                            enabled: !scope.typing || field.text !== ""
                            onClicked: card.submit()
                        }
                    }
                }
            }
        }
    }
}
