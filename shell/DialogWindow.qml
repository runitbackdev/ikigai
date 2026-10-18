import Quickshell
import Quickshell.Wayland
import QtQuick

// A full-screen dialog over everything with the screen dimmed behind it. The dim fades in
// on the window's first frame and out while `closing`, which the host holds for
// Motion.defaultEffects before dropping the window; meanwhile the window gives up the
// keyboard and lets clicks through, so a dying dialog holds nothing. A click on the dim
// or Escape is `dismissed`, an Enter nothing inside took is `accepted`.
PanelWindow {
    id: dialog

    property bool closing: false
    property string layerName
    default property alias content: holder.data

    signal dismissed()
    signal accepted()

    property bool entered: false

    screen: Screens.primary

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "ikigai:" + layerName
    color: "transparent"
    mask: Region {
        item: dialog.closing ? null : dim
    }

    // Opacity on a rectangle rather than the window's colour: one blended quad a frame.
    Rectangle {
        id: dim
        anchors.fill: parent
        color: "black"
        opacity: dialog.entered && !dialog.closing ? 0.5 : 0

        Behavior on opacity {
            Anim { effects: true }
        }

        Connections {
            target: dim.Window.window
            enabled: !dialog.entered

            function onFrameSwapped() {
                dialog.entered = true;
            }
        }

        Timer {
            interval: 250
            running: !dialog.entered
            onTriggered: dialog.entered = true
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !dialog.closing
        onClicked: dialog.dismissed()
    }

    Item {
        id: holder
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: if (!dialog.closing) dialog.dismissed()
        Keys.onReturnPressed: if (!dialog.closing) dialog.accepted()
        Keys.onEnterPressed: if (!dialog.closing) dialog.accepted()
    }
}
