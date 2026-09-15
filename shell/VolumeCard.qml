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
                    color: Audio.muted ? Theme.colors.fgVariant : Theme.colors.fg
                }
            }

            Item {
                id: slider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - mute.width - level.width - 2 * parent.spacing
                height: 24

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.colors.surfaceContainerHighest

                    Rectangle {
                        width: track.width * Audio.volume
                        height: parent.height
                        radius: parent.radius
                        color: Audio.muted ? Theme.colors.outline : Theme.colors.primary
                    }
                }

                Rectangle {
                    x: track.width * Audio.volume - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: Audio.muted ? Theme.colors.outline : Theme.colors.primary
                }

                MouseArea {
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

            Repeater {
                model: Audio.apps

                Item {
                    id: app
                    required property var modelData
                    // Read off the first stream, so the row follows a change made elsewhere.
                    readonly property var first: modelData.nodes.find(n => n.audio) || null
                    readonly property real volume: first && first.audio ? first.audio.volume : 0
                    readonly property bool muted: first && first.audio ? modelData.nodes.every(n => n.audio && n.audio.muted) : false

                    width: parent.width
                    height: 30

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

                    Text {
                        id: appName
                        anchors {
                            left: appMute.right
                            leftMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        width: 80
                        text: app.modelData.name
                        color: app.muted ? Theme.colors.fgVariant : Theme.colors.fg
                        font.family: Theme.fontFamily
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
                                width: appTrack.width * Math.min(1, app.volume)
                                height: parent.height
                                radius: parent.radius
                                color: app.muted ? Theme.colors.outline : Theme.colors.primary
                            }
                        }

                        Rectangle {
                            x: appTrack.width * Math.min(1, app.volume) - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: app.muted ? Theme.colors.outline : Theme.colors.primary
                        }

                        MouseArea {
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
                model: Audio.sinks

                Item {
                    id: row
                    required property var modelData
                    readonly property bool current: modelData === Audio.sink

                    width: parent.width
                    height: 30

                    StateLayer {
                        hovered: rowHover.hovered
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
                        visible: row.current
                    }

                    Text {
                        anchors.fill: parent
                        leftPadding: 28
                        rightPadding: 8
                        verticalAlignment: Text.AlignVCenter
                        text: Audio.nameOf(row.modelData)
                        color: row.current ? Theme.colors.fg : Theme.colors.fgVariant
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                    }

                    HoverHandler {
                        id: rowHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Audio.select(row.modelData)
                    }
                }
            }
        }
    }
}
