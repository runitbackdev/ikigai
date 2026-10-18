import QtQuick

// A red dot and the elapsed time while a recording runs; click to stop. Takes no room
// otherwise. Grows and shrinks, its gap above the clock included, so the cluster above
// slides to make room rather than jumping; the badge stays put and the edge uncovers it.
Item {
    id: badge

    readonly property int gap: 8

    implicitWidth: Theme.barWidth
    implicitHeight: Recorder.recording ? column.implicitHeight + gap : 0
    opacity: Recorder.recording ? 1 : 0
    visible: implicitHeight > 0
    clip: true

    Behavior on implicitHeight {
        Anim { standard: true }
    }

    Behavior on opacity {
        Anim { effects: true }
    }

    Column {
        id: column
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: badge.gap
        }
        spacing: 2

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(10 * Config.scale)
            height: width
            radius: width / 2
            color: Theme.colors.error

            SequentialAnimation on opacity {
                running: Recorder.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Recorder.elapsed
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
        }
    }

    MouseArea {
        anchors.fill: column
        cursorShape: Qt.PointingHandCursor
        onClicked: Recorder.stop()
    }
}
