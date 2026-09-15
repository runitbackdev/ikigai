import QtQuick

// The caffeine card, on a right-click of the cup: how long to keep the screen on, and
// Off while it is.
PopupCard {
    id: card

    implicitWidth: 200
    implicitHeight: rows.implicitHeight + 12

    component Entry: Item {
        id: entry

        property string label
        property bool checked: false

        signal activated

        width: rows.width
        height: 32

        StateLayer {
            hovered: entryHover.hovered
        }

        Text {
            anchors.fill: parent
            leftPadding: 12
            rightPadding: 30
            verticalAlignment: Text.AlignVCenter
            text: entry.label
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            elide: Text.ElideRight
        }

        Glyph {
            anchors {
                right: parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            name: "check"
            size: 14
            color: Theme.colors.primary
            visible: entry.checked
        }

        HoverHandler {
            id: entryHover
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                card.done();
                entry.activated();
            }
        }
    }

    Column {
        id: rows
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        Repeater {
            model: Caffeine.choices

            Entry {
                required property var modelData
                label: modelData.label
                checked: Caffeine.active && Caffeine.minutes === modelData.minutes
                onActivated: Caffeine.start(modelData.minutes)
            }
        }

        Entry {
            visible: Caffeine.active
            label: Caffeine.until > 0 ? "Off (ends " + Qt.formatTime(new Date(Caffeine.until), "h:mm ap") + ")" : "Off"
            onActivated: Caffeine.stop()
        }
    }
}
