import Quickshell
import QtQuick

// One window, in the switcher or the rail's window list: icon and title over a preview of
// the window, or the app icon until the bridge has captured it. `closable` adds a close
// control on hover and middle-click.
Item {
    id: tile

    property var entry: null
    property bool selected: false
    property bool closable: false

    signal clicked
    signal closeRequested

    readonly property int inset: Math.round(8 * Config.scale)
    readonly property string icon: Quickshell.iconPath(Apps.iconFor(entry ? entry.appId : ""), "application-x-executable")
    readonly property var thumb: entry ? Bridge.thumbs[entry.id] : undefined

    height: header.height + inset * 3 + preview.height

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius + tile.inset
        color: tile.selected ? Theme.colors.surfaceContainerHigh : "transparent"
        border.width: 1
        border.color: tile.selected ? Theme.colors.primary : "transparent"

        Behavior on color {
            ColorAnim {}
        }

        Behavior on border.color {
            ColorAnim {}
        }

        StateLayer {
            radius: parent.radius
            hovered: hover.hovered
            pressed: press.pressed
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: press
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton && tile.closable)
                tile.closeRequested();
            else if (mouse.button === Qt.LeftButton)
                tile.clicked();
        }
    }

    Item {
        id: header
        x: tile.inset
        y: tile.inset
        z: 1
        width: parent.width - 2 * tile.inset
        height: Math.round(20 * Config.scale)

        AppIcon {
            id: smallIcon
            anchors.verticalCenter: parent.verticalCenter
            size: 16
            source: tile.icon
        }

        Text {
            anchors {
                left: smallIcon.right
                leftMargin: 8
                right: closeGlyph.visible ? closeGlyph.left : parent.right
                verticalCenter: parent.verticalCenter
            }
            text: tile.entry ? tile.entry.title : ""
            elide: Text.ElideRight
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
        }

        // Close control: a round button that turns to the error colour under the pointer,
        // like the X on a Windows switcher tile.
        Rectangle {
            id: closeGlyph
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: Math.round(22 * Config.scale)
            height: width
            radius: width / 2
            visible: tile.closable
            color: closeHover.hovered ? Theme.colors.error : "transparent"
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity {
                Anim { effects: true }
            }

            Behavior on color {
                ColorAnim {}
            }

            Glyph {
                anchors.centerIn: parent
                name: "x"
                size: 14
                color: closeHover.hovered ? Theme.colors.surface : Theme.colors.fgVariant
            }

            HoverHandler {
                id: closeHover
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: tile.closeRequested()
            }
        }
    }

    Rectangle {
        id: preview
        x: tile.inset
        y: header.y + header.height + tile.inset
        width: parent.width - 2 * tile.inset
        height: Math.round(width * 9 / 16)
        radius: Theme.radius
        color: Theme.colors.surfaceContainerLow

        AppIcon {
            anchors.centerIn: parent
            size: 48
            source: tile.icon
            visible: shot.status !== Image.Ready
        }

        Image {
            id: shot
            anchors.fill: parent
            anchors.margins: 4
            source: tile.thumb ? "file://" + tile.thumb.path : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
        }
    }

}
