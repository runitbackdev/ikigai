import Quickshell
import QtQuick

// A column of task buttons for one pinned group. A button grows in when its app opens
// and the others glide aside. The height eases on the same curve as that glide: the
// lower group hangs from its bottom edge and grows upward, and moving its top edge in
// step with the buttons' y keeps the ones below the change still on screen.
Item {
    id: group

    required property var tasks

    signal menuRequested(var task, Item at)
    signal windowsRequested(var task, Item at)
    signal dismissRequested

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    // Not from nothing: the first layout, or a first app in an empty group, just lands.
    Behavior on implicitHeight {
        enabled: group.implicitHeight > 0
        Anim {}
    }

    Column {
        id: column
        spacing: 4

        add: Transition {
            Anim { property: "grow"; from: 0; to: 1 }
        }

        // Settles grow too, in case a move cuts an add short.
        move: Transition {
            Anim { property: "y" }
            Anim { property: "grow"; to: 1 }
        }

        Repeater {
            model: ScriptModel {
                values: group.tasks
                objectProp: "appId"
            }

            TaskButton {
                onMenuRequested: group.menuRequested(task, this)
                onWindowsRequested: group.windowsRequested(task, this)
                onDismissRequested: group.dismissRequested()
            }
        }
    }
}
