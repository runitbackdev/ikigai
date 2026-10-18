import Quickshell
import QtQuick

// The network card: the Wi-Fi switch and a rescan, the wired link when it is up, then
// the networks in range. A click connects (saved and open networks straight away, a new
// secured one through the password window); the connected row and, on right-click, a
// saved one expand to Disconnect and Forget.
PopupCard {
    id: card

    property string expanded: ""

    implicitWidth: 280
    implicitHeight: column.implicitHeight + 24

    onShownChanged: {
        expanded = "";
        if (shown)
            Network.scan();
    }

    Timer {
        interval: 15000
        repeat: true
        running: card.shown
        onTriggered: Network.scan()
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
                checked: Network.wifiEnabled
                visible: Network.wifiHardware
                onClicked: Network.setWifi(!Network.wifiEnabled)

                Glyph {
                    anchors.centerIn: parent
                    name: Network.wifiEnabled ? "wifi-high" : "wifi-slash"
                    size: Theme.iconSize
                    animate: true
                    color: Network.wifiEnabled ? Theme.colors.primary : Theme.colors.fgVariant
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (toggle.visible ? toggle.width + parent.spacing : 0) - rescan.width - parent.spacing
                spacing: 1

                Text {
                    text: !Network.wifiHardware ? "No Wi-Fi hardware" : Network.wifiEnabled ? "Wi-Fi" : "Wi-Fi is off"
                    color: Theme.colors.fg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: Font.Medium
                }

                Words {
                    width: parent.width
                    text: Network.pending !== "" ? "Connecting to " + Network.pending : Network.error !== "" ? Network.error : Network.ssid !== "" ? "Connected to " + Network.ssid : ""
                    visible: text !== ""
                    color: Network.error !== "" && Network.pending === "" ? Theme.colors.error : Theme.colors.fgVariant
                    font.pointSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                }
            }

            BarButton {
                id: rescan
                anchors.verticalCenter: parent.verticalCenter
                visible: Network.wifiHardware && Network.wifiEnabled
                onClicked: Network.scan()

                Glyph {
                    anchors.centerIn: parent
                    name: "arrows-clockwise"
                    size: 16
                    color: Theme.colors.fgVariant
                }
            }
        }

        Item {
            width: parent.width
            height: 30
            visible: Network.wired

            Glyph {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                name: "brand:ethernet"
                size: 16
                color: Theme.colors.primary
            }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 34
                    verticalCenter: parent.verticalCenter
                }
                text: "Wired"
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
            }

            Text {
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: "Connected"
                color: Theme.colors.fgVariant
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
            }
        }

        // Each scan builds new objects; keyed on the SSID, rows keep their hover and
        // aren't rebuilt every 15 s. Empty while the card is hidden, so a change in range
        // doesn't diff rows nobody sees.
        Repeater {
            model: ScriptModel {
                values: card.live && Network.wifiEnabled ? Network.networks : []
                objectProp: "ssid"
            }

            Column {
                id: row

                required property var modelData
                readonly property bool open: card.expanded === modelData.ssid

                width: parent.width

                Item {
                    width: parent.width
                    height: 30

                    StateLayer {
                        hovered: rowHover.hovered
                        pressed: rowPress.pressed
                        active: row.modelData.active
                    }

                    Glyph {
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        name: Network.wifiIcon(row.modelData.strength)
                        size: 16
                        animate: true
                        color: row.modelData.active ? Theme.colors.primary : Theme.colors.fg
                    }

                    Words {
                        anchors {
                            left: parent.left
                            leftMargin: 34
                            right: lock.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: row.modelData.ssid
                        color: row.modelData.active ? Theme.colors.primary : Theme.colors.fg
                        elide: Text.ElideRight
                    }

                    Glyph {
                        id: lock
                        anchors {
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        name: row.modelData.active ? "check" : "lock-simple"
                        size: 14
                        animate: true
                        visible: row.modelData.active || row.modelData.secure
                        color: row.modelData.active ? Theme.colors.primary : Theme.colors.outline
                    }

                    HoverHandler {
                        id: rowHover
                    }

                    MouseArea {
                        id: rowPress
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            const n = row.modelData;
                            if (mouse.button === Qt.RightButton || n.active)
                                card.expanded = row.open || !(n.saved || n.active) ? "" : n.ssid;
                            else if (n.saved || !n.secure)
                                Network.connect(n.ssid, "");
                            else
                                Network.asking = n.ssid;
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
                        visible: row.modelData.active
                        height: 28
                        onClicked: {
                            card.expanded = "";
                            Network.disconnect();
                        }
                    }

                    Pill {
                        label: "Forget"
                        visible: row.modelData.saved
                        height: 28
                        onClicked: {
                            card.expanded = "";
                            Network.forget(row.modelData.ssid);
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            height: 30
            text: "No networks found"
            visible: Network.wifiHardware && Network.wifiEnabled && Network.networks.length === 0
            color: Theme.colors.outline
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
