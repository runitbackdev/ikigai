import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    property int step: 0
    PanelWindow {
        id: win
        anchors { top: true; left: true }
        implicitWidth: 200; implicitHeight: 100
        color: "#cc3366"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ikigai-hide-test"
        Text { anchors.centerIn: parent; text: "step " + step; color: "white" }
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            step++
            if (step >= 7) { console.log("hide-test: survived " + (step - 1) + " toggles, exiting 0"); Qt.exit(0); return }
            win.visible = !win.visible
            console.log("hide-test: step " + step + " visible=" + win.visible)
        }
    }
}
