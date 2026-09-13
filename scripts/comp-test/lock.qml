import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    property int step: 0
    WlSessionLock {
        id: lock
        WlSessionLockSurface { color: "#336699"; Text { anchors.centerIn: parent; text: "locked " + step; color: "white" } }
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            step++
            if (step >= 5) { console.log("lock-test: survived " + (step - 1) + " lock/unlock steps, exiting 0"); Qt.exit(0); return }
            lock.locked = !lock.locked
            console.log("lock-test: step " + step + " locked=" + lock.locked)
        }
    }
}
