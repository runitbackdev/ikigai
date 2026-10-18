import QtQuick

// The on-screen display: a pill out of the frame's bottom border with a glyph, a bar and
// the level. Bar draws it as a blob sized by `reveal`, and the content rides up with the
// blob's top edge, so it never shows over the desktop ahead of its surface.
Item {
    id: pill

    property real reveal: Osd.shown ? 1 : 0

    implicitWidth: Math.round(220 * Config.scale)
    implicitHeight: Math.round(44 * Config.scale)
    opacity: Math.max(0, Math.min(1, reveal * 2))
    visible: reveal > 0
    clip: true

    Behavior on reveal {
        Anim {}
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        // Held at rest while the blob overshoots, so its top isn't clipped.
        y: Math.round((pill.height - height) / 2 + Math.max(0, 1 - pill.reveal) * (pill.height + 50))
        spacing: Math.round(12 * Config.scale)

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            name: Osd.icon
            size: Theme.iconSize
            color: Osd.muted ? Theme.colors.fgVariant : Theme.colors.fg
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(110 * Config.scale)
            height: 6
            radius: 3
            color: Theme.colors.surfaceContainerHighest

            Rectangle {
                width: track.width * Osd.value
                height: parent.height
                radius: parent.radius
                color: Osd.muted ? Theme.colors.outline : Theme.colors.primary

                Behavior on color {
                    ColorAnim {}
                }

                // A level has a ceiling; overshoot would read high and poke past the track.
                Behavior on width {
                    Anim { standard: true }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(34 * Config.scale)
            text: Math.round(Osd.value * 100)
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            horizontalAlignment: Text.AlignRight
        }
    }
}
