import Quickshell
import QtQuick

// The volume card: mute and a slider, when there is more than one output the list of
// them to pick the default from, and a row per app playing sound with its own level
// and mute.
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
        spacing: 8

        Row {
            width: parent.width
            spacing: 8

            BarButton {
                id: mute
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Audio.toggleMute()

                Glyph {
                    anchors.centerIn: parent
                    name: Audio.icon
                    size: Theme.iconSize
                    animate: true
                    color: Audio.muted ? Theme.colors.fgVariant : Theme.colors.fg
                }
            }

            Item {
                id: slider

                // The level the fill and knob draw, eased so a wheel step or a change made
                // elsewhere glides like the OSD; a drag follows the pointer directly. A
                // fraction rather than a width, so the first layout doesn't sweep the fill.
                property real fraction: Audio.volume

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - mute.width - level.width - 2 * parent.spacing
                height: 24

                // Not while hidden: the OSD shows a change made elsewhere then.
                Behavior on fraction {
                    enabled: !press.pressed && card.live
                    Anim { standard: true }
                }

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.colors.surfaceContainerHighest

                    Rectangle {
                        width: track.width * slider.fraction
                        height: parent.height
                        radius: parent.radius
                        color: Audio.muted ? Theme.colors.outline : Theme.colors.primary

                        Behavior on color {
                            ColorAnim {}
                        }
                    }
                }

                Rectangle {
                    x: track.width * slider.fraction - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: press.pressed ? 18 : 14
                    height: width
                    radius: width / 2
                    color: Audio.muted ? Theme.colors.outline : Theme.colors.primary

                    Behavior on width {
                        Anim { fast: true }
                    }

                    Behavior on color {
                        ColorAnim {}
                    }
                }

                MouseArea {
                    id: press
                    anchors.fill: parent
                    onPressed: mouse => Audio.setVolume(mouse.x / width)
                    onPositionChanged: mouse => { if (pressed) Audio.setVolume(mouse.x / width); }
                }

                WheelHandler {
                    onWheel: event => Audio.step(event.angleDelta.y > 0 ? 0.05 : -0.05)
                }
            }

            Text {
                id: level
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                text: Math.round(Audio.volume * 100)
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                horizontalAlignment: Text.AlignRight
            }
        }

        Column {
            width: parent.width
            visible: Audio.apps.length > 0
            spacing: 2

            Rectangle {
                width: parent.width - 16
                x: 8
                height: 1
                color: Theme.colors.outlineVariant
            }

            // Keyed on the name, so a stream opening elsewhere (a notification sound)
            // doesn't rebuild the rows under a drag. Empty while the card is hidden: each
            // row follows its streams' levels.
            Repeater {
                model: ScriptModel {
                    values: card.live ? Audio.apps : []
                    objectProp: "name"
                }

                Item {
                    id: app
                    required property var modelData
                    // Read off the first stream, so the row follows a change made elsewhere.
                    readonly property var first: modelData.nodes.find(n => n.audio) || null
                    readonly property real volume: first && first.audio ? first.audio.volume : 0
                    readonly property bool muted: first && first.audio ? modelData.nodes.every(n => n.audio && n.audio.muted) : false
                    property real fraction: Math.min(1, volume)

                    width: parent.width
                    height: 30

                    Behavior on fraction {
                        enabled: !appPress.pressed
                        Anim { standard: true }
                    }

                    BarButton {
                        id: appMute
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 26
                        implicitHeight: 26
                        onClicked: Audio.toggleAppMute(app.modelData)

                        Glyph {
                            anchors.centerIn: parent
                            name: app.modelData.glyph
                            size: Theme.iconSize - 4
                            color: app.muted ? Theme.colors.fgVariant : Theme.colors.fg
                        }
                    }

                    Words {
                        id: appName
                        anchors {
                            left: appMute.right
                            leftMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        width: 80
                        text: app.modelData.name
                        color: app.muted ? Theme.colors.fgVariant : Theme.colors.fg
                        font.pointSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                    }

                    Item {
                        id: appSlider
                        anchors {
                            left: appName.right
                            leftMargin: 8
                            right: appLevel.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        height: 20

                        Rectangle {
                            id: appTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Theme.colors.surfaceContainerHighest

                            Rectangle {
                                width: appTrack.width * app.fraction
                                height: parent.height
                                radius: parent.radius
                                color: app.muted ? Theme.colors.outline : Theme.colors.primary

                                Behavior on color {
                                    ColorAnim {}
                                }
                            }
                        }

                        Rectangle {
                            x: appTrack.width * app.fraction - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: appPress.pressed ? 14 : 10
                            height: width
                            radius: width / 2
                            color: app.muted ? Theme.colors.outline : Theme.colors.primary

                            Behavior on width {
                                Anim { fast: true }
                            }

                            Behavior on color {
                                ColorAnim {}
                            }
                        }

                        MouseArea {
                            id: appPress
                            anchors.fill: parent
                            onPressed: mouse => Audio.setAppVolume(app.modelData, mouse.x / width)
                            onPositionChanged: mouse => { if (pressed) Audio.setAppVolume(app.modelData, mouse.x / width); }
                        }

                        WheelHandler {
                            onWheel: event => Audio.setAppVolume(app.modelData, app.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
                        }
                    }

                    Text {
                        id: appLevel
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        width: 30
                        text: Math.round(app.volume * 100)
                        color: Theme.colors.fgVariant
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        Column {
            width: parent.width
            visible: Audio.sinks.length > 1

            Repeater {
                model: ScriptModel {
                    values: card.live ? Audio.sinks : []
                }

                Item {
                    id: row
                    required property var modelData
                    readonly property bool current: modelData === Audio.sink

                    width: parent.width
                    height: 30

                    StateLayer {
                        hovered: rowHover.hovered
                        pressed: rowPress.pressed
                    }

                    Glyph {
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        name: "check"
                        size: 14
                        color: Theme.colors.primary
                        opacity: row.current ? 1 : 0

                        // Fades with the label beside it as the default moves.
                        Behavior on opacity {
                            Anim { effects: true }
                        }
                    }

                    Words {
                        anchors.fill: parent
                        leftPadding: 28
                        rightPadding: 8
                        verticalAlignment: Text.AlignVCenter
                        text: Audio.nameOf(row.modelData)
                        color: row.current ? Theme.colors.fg : Theme.colors.fgVariant
                        font.pointSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                    }

                    HoverHandler {
                        id: rowHover
                    }

                    MouseArea {
                        id: rowPress
                        anchors.fill: parent
                        onClicked: Audio.select(row.modelData)
                    }
                }
            }
        }
    }
}
