import Quickshell.Services.UPower
import QtQuick

// The battery card: level and state, then the power profile to pick from.
PopupCard {
    id: card

    implicitWidth: 260
    implicitHeight: column.implicitHeight + 24

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 6
        }
        spacing: 10

        Row {
            width: parent.width
            spacing: 10

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: Power.icon
                size: 26
                animate: true
                color: Power.low ? Theme.colors.error : Theme.colors.fg
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: Math.round(Power.percentage) + "%"
                    color: Theme.colors.fg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize + 2
                    font.weight: Font.Medium
                }

                Text {
                    text: Power.status
                    color: Theme.colors.fgVariant
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                }
            }
        }

        Rectangle {
            id: track
            width: parent.width
            height: 6
            radius: 3
            color: Theme.colors.surfaceContainerHighest

            Rectangle {
                width: track.width * Power.percentage / 100
                height: parent.height
                radius: parent.radius
                color: Power.low ? Theme.colors.error : Theme.colors.primary

                // A fill stops at the track's end, so no overshoot.
                Behavior on width {
                    Anim { standard: true }
                }

                Behavior on color {
                    ColorAnim {}
                }
            }
        }

        Row {
            id: profiles

            readonly property int cells: PowerProfiles.hasPerformanceProfile ? 3 : 2

            width: parent.width

            Repeater {
                model: Power.profiles

                Item {
                    id: cell

                    required property var modelData
                    readonly property bool current: PowerProfiles.profile === modelData.profile

                    width: profiles.width / profiles.cells
                    height: 52
                    visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile

                    StateLayer {
                        hovered: cellHover.hovered
                        pressed: cellPress.pressed
                        active: cell.current
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: cell.modelData.icon
                            size: 18
                            color: cell.current ? Theme.colors.primary : Theme.colors.fgVariant
                        }

                        Words {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.label
                            color: cell.current ? Theme.colors.primary : Theme.colors.fgVariant
                            font.pointSize: Theme.fontSize - 2
                        }
                    }

                    HoverHandler {
                        id: cellHover
                    }

                    MouseArea {
                        id: cellPress
                        anchors.fill: parent
                        onClicked: Power.setProfile(cell.modelData.profile)
                    }
                }
            }
        }
    }
}
