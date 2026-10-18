import QtQuick

// A labelled pill button: tinted surface, or filled with the primary colour for the one
// action a card wants pressed.
Rectangle {
    id: pill

    property string label
    property bool primary: false
    property bool enabled: true

    signal clicked

    width: text.width + Math.round(28 * Config.scale)
    height: Math.round(36 * Config.scale)
    radius: height / 2
    color: primary ? Theme.colors.primary : Theme.colors.surfaceContainerHigh
    opacity: enabled ? 1 : 0.5

    Behavior on color {
        ColorAnim {}
    }

    Behavior on opacity {
        Anim { effects: true }
    }

    Words {
        id: text
        anchors.centerIn: parent
        text: pill.label
        color: pill.primary ? Theme.colors.primaryFg : Theme.colors.primary
        font.weight: Font.Medium
    }

    StateLayer {
        radius: parent.radius
        hovered: hover.hovered
        pressed: press.pressed
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: press
        anchors.fill: parent
        enabled: pill.enabled
        onClicked: pill.clicked()
    }
}
