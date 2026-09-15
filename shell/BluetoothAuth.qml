import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// The pairing prompt, in the Wi-Fi password window's shape: a number to confirm, a code
// to type on the device, a PIN or passkey to type here, or a yes/no for a device that
// wants in. Opens while Bluetooth.request is set; Enter answers where there is a field,
// Escape or a click outside refuses.
Scope {
    id: scope

    readonly property var request: Bluetooth.request
    readonly property bool typing: request && (request.kind === "pin" || request.kind === "passkey")
    readonly property string title: !request ? "" : request.kind === "display" ? "Pair " + request.name
        : request.kind === "confirm" ? "Pair " + request.name
        : request.kind === "authorize" ? request.name + " wants to connect"
        : request.kind === "service" ? request.name + " wants to use a service" : "Pair " + request.name
    readonly property string detail: !request ? "" : request.kind === "display" ? "Type this on the device, then Enter there."
        : request.kind === "confirm" ? "Confirm the number shows on the device too."
        : request.kind === "pin" ? "The device wants a PIN."
        : request.kind === "passkey" ? "The device wants a six-digit passkey."
        : request.kind === "service" ? request.uuid : "Allow it?"

    function refuse() {
        Bluetooth.answer(false);
    }

    LazyLoader {
        active: scope.request !== null

        PanelWindow {
            screen: Screens.primary

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:bluetooth"
            color: Qt.alpha("black", 0.5)

            MouseArea {
                anchors.fill: parent
                onClicked: scope.refuse()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: scope.refuse()
                Keys.onReturnPressed: card.submit()
                Keys.onEnterPressed: card.submit()

                Rectangle {
                    id: card

                    readonly property int pad: Math.round(28 * Config.scale)
                    readonly property int fieldWidth: Math.round(300 * Config.scale)

                    anchors.centerIn: parent
                    width: column.width + 2 * pad
                    height: column.height + 2 * pad
                    radius: Theme.cardRadius
                    color: Theme.colors.surface
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        blurMax: 15
                        shadowColor: Qt.alpha("black", 0.6)
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

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

                    Column {
                        id: column
                        x: card.pad
                        y: card.pad
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
                            visible: scope.request && (scope.request.kind === "confirm" || scope.request.kind === "display")
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            Repeater {
                                model: scope.request && scope.request.passkey ? scope.request.passkey.split("") : []

                                Text {
                                    required property string modelData
                                    required property int index
                                    text: modelData
                                    color: scope.request && scope.request.kind === "display" && index >= (scope.request.entered || 0) ? Theme.colors.fgVariant : Theme.colors.fg
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
                                inputMethodHints: scope.request && scope.request.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
                                validator: RegularExpressionValidator {
                                    regularExpression: scope.request && scope.request.kind === "passkey" ? /[0-9]{0,6}/ : /.{0,16}/
                                }
                                clip: true
                                Component.onCompleted: if (scope.typing) forceActiveFocus()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: scope.request && scope.request.kind === "passkey" ? "Passkey" : "PIN"
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
                                visible: scope.request && scope.request.kind !== "display"
                                label: scope.request && (scope.request.kind === "authorize" || scope.request.kind === "service") ? "Allow" : scope.request && scope.request.kind === "confirm" ? "Matches" : "Pair"
                                enabled: !scope.typing || field.text !== ""
                                onClicked: card.submit()
                            }
                        }
                    }
                }
            }
        }
    }
}
