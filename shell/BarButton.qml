import QtQuick

// A square bar button: hover surface, optional checked state, content centred inside.
Item {
    id: button

    property bool checked: false
    default property alias content: slot.data

    signal clicked
    signal rightClicked
    signal middleClicked

    implicitWidth: Theme.barWidth - 8
    implicitHeight: Theme.barWidth - 8

    // Springs down on press and back with overshoot.
    scale: press.pressed ? 0.88 : 1

    Behavior on scale {
        Anim { fast: true }
    }

    StateLayer {
        hovered: hover.hovered
        pressed: press.pressed
        active: button.checked
    }

    Item {
        id: slot
        anchors.centerIn: parent
        width: 18
        height: 18
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: press
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                button.rightClicked();
            else if (mouse.button === Qt.MiddleButton)
                button.middleClicked();
            else
                button.clicked();
        }
    }
}
