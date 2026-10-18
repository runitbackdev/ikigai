import Quickshell
import QtQuick

// The sidebar: notification history under a do-not-disturb toggle and a clear button,
// then a month calendar. Hangs out of the frame's right border; Bar draws it as a blob
// and, while it is open, takes input over the whole screen so a click elsewhere closes it.
// Bar sizes the blob by `reveal`, and the content slides with the blob's left edge.
Item {
    id: sidebar

    property bool active: true
    readonly property bool open: active && Notifs.sidebarOpen
    readonly property int pad: Math.round(16 * Config.scale)
    property real reveal: open ? 1 : 0

    width: Math.round(360 * Config.scale)
    opacity: Math.max(0, Math.min(1, reveal * 2))
    visible: reveal > 0
    clip: true

    Behavior on reveal {
        Anim {}
    }

    // Clear fades the list out first, rather than fifty rows leaving at once, and empties
    // it while hidden; the list comes back once the rows are gone.
    Timer {
        id: clearing
        interval: Motion.defaultEffects
        onTriggered: {
            Notifs.clear();
            settle.restart();
        }
    }

    Timer {
        id: settle
        interval: Motion.fastEffects
        onTriggered: list.emptying = false
    }

    Column {
        id: column
        anchors {
            fill: parent
            margins: sidebar.pad
        }
        spacing: sidebar.pad
        // Held at rest while the blob overshoots, so its left edge isn't clipped.
        transform: Translate {
            x: Math.max(0, 1 - sidebar.reveal) * (sidebar.width + 50)
        }

        Item {
            id: header
            width: parent.width
            height: Theme.barWidth - 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 1
                font.weight: Font.Medium
            }

            Row {
                anchors.right: parent.right
                spacing: 4

                BarButton {
                    checked: Config.dnd
                    onClicked: Config.setDnd(!Config.dnd)

                    Glyph {
                        anchors.centerIn: parent
                        name: Config.dnd ? "bell-slash" : "bell"
                        size: 18
                        color: Config.dnd ? Theme.colors.primary : Theme.colors.fgVariant
                    }
                }

                BarButton {
                    visible: Notifs.history.length > 0
                    onClicked: {
                        list.emptying = true;
                        clearing.restart();
                    }

                    Glyph {
                        anchors.centerIn: parent
                        name: "broom"
                        size: 18
                        color: Theme.colors.fgVariant
                    }
                }
            }
        }

        ListView {
            id: list

            // Mid-clear: hidden, and its rows leave without their exit.
            property bool emptying: false

            width: parent.width
            height: parent.height - header.height - calendar.height - 2 * column.spacing
            clip: true
            spacing: Math.round(8 * Config.scale)
            maximumFlickVelocity: 3000
            opacity: emptying ? 0 : 1
            model: ScriptModel {
                values: Notifs.history
            }

            Behavior on opacity {
                Anim { effects: true }
            }

            add: Transition {
                Anim { property: "opacity"; from: 0; to: 1; effects: true }
                Anim { property: "scale"; from: 0.8; to: 1 }
            }

            // Shrinks rather than slides: sliding sideways would poke past the panel.
            remove: Transition {
                enabled: !list.emptying
                Anim { property: "opacity"; to: 0; effects: true }
                Anim { property: "scale"; to: 0.6; standard: true }
            }

            // Settle anything a cut-short add left half faded.
            displaced: Transition {
                Anim { property: "y" }
                Anim { properties: "opacity,scale"; to: 1; effects: true }
            }

            rebound: Transition {
                Anim { properties: "x,y" }
            }

            Text {
                anchors.centerIn: parent
                text: Config.dnd ? "Do not disturb is on" : "No notifications"
                visible: Notifs.history.length === 0
                color: Theme.colors.outline
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
            }

            delegate: Rectangle {
                id: entry

                required property var modelData
                readonly property int inset: Math.round(12 * Config.scale)
                readonly property int iconSize: Math.round(28 * Config.scale)

                width: list.width
                height: body.implicitHeight + 2 * inset
                radius: Theme.radius + 4
                color: Theme.colors.surfaceContainerLow

                StateLayer {
                    radius: parent.radius
                    hovered: entryHover.hovered
                    pressed: entryMouse.pressed
                }

                HoverHandler {
                    id: entryHover
                }

                MouseArea {
                    id: entryMouse
                    anchors.fill: parent
                    onClicked: Notifs.remove(entry.modelData)
                }

                Row {
                    id: body
                    x: entry.inset
                    y: entry.inset
                    width: parent.width - 2 * entry.inset
                    spacing: Math.round(10 * Config.scale)

                    AppIcon {
                        source: entry.modelData.icon
                        size: entry.iconSize
                    }

                    Column {
                        width: parent.width - entry.iconSize - parent.spacing
                        spacing: 2

                        Item {
                            width: parent.width
                            height: app.implicitHeight

                            Text {
                                id: app
                                text: entry.modelData.appName
                                color: Theme.colors.fgVariant
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 3
                            }

                            Text {
                                anchors.right: parent.right
                                text: Qt.formatTime(entry.modelData.time, "h:mm AP")
                                color: Theme.colors.outline
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 3
                            }
                        }

                        Text {
                            width: parent.width
                            text: entry.modelData.summary
                            color: Theme.colors.fg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            font.weight: Font.Medium
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: entry.modelData.body
                            visible: text !== ""
                            color: Theme.colors.fgVariant
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Calendar {
            id: calendar
            width: parent.width
        }
    }
}
