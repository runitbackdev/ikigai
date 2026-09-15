import Quickshell.Bluetooth as Bluez
import QtQuick

// The Bluetooth card: the switch, the devices paired or in range (searching while the
// card is open), a click to connect or pair; the connected row and, on right-click, a
// paired one expand to Disconnect and Forget. Pairing that needs a PIN or a confirmation
// gets a prompt of its own (BluetoothAuth), through the agent Bluetooth runs.
PopupCard {
    id: card

    property string expanded: ""

    implicitWidth: 280
    implicitHeight: column.implicitHeight + 24

    onShownChanged: {
        expanded = "";
        Bluetooth.setDiscovering(shown);
    }

    Connections {
        target: Bluetooth
        function onEnabledChanged() {
            if (card.shown)
                Bluetooth.setDiscovering(Bluetooth.enabled);
        }
    }

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 6
        }
        spacing: 4

        Row {
            width: parent.width
            spacing: 8

            BarButton {
                id: toggle
                anchors.verticalCenter: parent.verticalCenter
                checked: Bluetooth.enabled
                visible: Bluetooth.present
                onClicked: Bluetooth.setEnabled(!Bluetooth.enabled)

                Glyph {
                    anchors.centerIn: parent
                    name: Bluetooth.enabled ? "bluetooth" : "bluetooth-slash"
                    size: Theme.iconSize
                    color: Bluetooth.enabled ? Theme.colors.primary : Theme.colors.fgVariant
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (toggle.visible ? toggle.width + parent.spacing : 0) - search.width - parent.spacing
                spacing: 1

                Text {
                    text: !Bluetooth.present ? "No Bluetooth hardware" : Bluetooth.enabled ? "Bluetooth" : "Bluetooth is off"
                    color: Theme.colors.fg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: Bluetooth.error !== "" ? Bluetooth.error : Bluetooth.enabled && Bluetooth.connectedCount > 0 ? "Connected to " + Bluetooth.connectedNames() : Bluetooth.enabled && Bluetooth.discovering ? "Searching…" : ""
                    visible: text !== ""
                    color: Bluetooth.error !== "" ? Theme.colors.error : Theme.colors.fgVariant
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                }
            }

            BarButton {
                id: search
                anchors.verticalCenter: parent.verticalCenter
                visible: Bluetooth.enabled
                checked: Bluetooth.discovering
                onClicked: Bluetooth.setDiscovering(!Bluetooth.discovering)

                Glyph {
                    anchors.centerIn: parent
                    name: "magnifying-glass"
                    size: 16
                    color: Bluetooth.discovering ? Theme.colors.primary : Theme.colors.fgVariant
                }
            }
        }

        Repeater {
            model: Bluetooth.enabled ? Bluetooth.listed : []

            Column {
                id: row

                required property Bluez.BluetoothDevice modelData
                readonly property bool paired: modelData.paired || modelData.bonded
                readonly property bool busy: modelData.pairing || modelData.state === Bluez.BluetoothDeviceState.Connecting || modelData.state === Bluez.BluetoothDeviceState.Disconnecting
                readonly property bool open: card.expanded === modelData.address
                readonly property string detail: modelData.pairing ? "Pairing…" : modelData.state === Bluez.BluetoothDeviceState.Connecting ? "Connecting…" : modelData.state === Bluez.BluetoothDeviceState.Disconnecting ? "Disconnecting…" : modelData.connected && modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""

                width: parent.width

                Item {
                    width: parent.width
                    height: 30

                    StateLayer {
                        hovered: rowHover.hovered
                        active: row.modelData.connected
                    }

                    Glyph {
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        name: Bluetooth.glyphFor(row.modelData)
                        size: 16
                        color: row.modelData.connected ? Theme.colors.primary : row.paired ? Theme.colors.fg : Theme.colors.fgVariant
                    }

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 34
                            right: detail.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: row.modelData.name
                        color: row.modelData.connected ? Theme.colors.primary : row.paired ? Theme.colors.fg : Theme.colors.fgVariant
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    Text {
                        id: detail
                        anchors {
                            right: mark.visible ? mark.left : parent.right
                            rightMargin: mark.visible ? 6 : 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: row.detail
                        visible: text !== ""
                        color: Theme.colors.fgVariant
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                    }

                    Glyph {
                        id: mark
                        anchors {
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        name: "check"
                        size: 14
                        visible: row.modelData.connected
                        color: Theme.colors.primary
                    }

                    HoverHandler {
                        id: rowHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            const d = row.modelData;
                            if (mouse.button === Qt.RightButton || d.connected)
                                card.expanded = row.open || !(row.paired || d.connected || d.pairing) ? "" : d.address;
                            else if (d.pairing)
                                d.cancelPair();
                            else if (!row.busy)
                                Bluetooth.connect(d);
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    rightPadding: 8
                    bottomPadding: 6
                    spacing: 6
                    visible: row.open

                    Pill {
                        label: "Disconnect"
                        visible: row.modelData.connected
                        height: 28
                        onClicked: {
                            card.expanded = "";
                            Bluetooth.disconnect(row.modelData);
                        }
                    }

                    Pill {
                        label: "Forget"
                        visible: row.paired
                        height: 28
                        onClicked: {
                            card.expanded = "";
                            Bluetooth.forget(row.modelData);
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            height: 30
            text: Bluetooth.discovering ? "Searching…" : "No devices found"
            visible: Bluetooth.enabled && Bluetooth.listed.length === 0
            color: Theme.colors.outline
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
