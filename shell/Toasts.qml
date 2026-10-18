import Quickshell
import QtQuick

// The toast stack: one sheet hanging from the frame's top border at the right, which Bar
// draws as a blob and masks for input. The sheet's extent is eased here and the rows are
// clipped to it, so its growing edge reveals them; rows slide in from the screen edge and
// shuffle up as others leave.
Item {
    id: toasts

    readonly property alias hovered: hover.hovered
    // Off on the other screens: an empty stack takes no space, so Bar's blob and mask
    // collapse with it.
    property bool active: true
    // Tucked away under an open sidebar; the rows stay, so the sheet draws back over them.
    property bool shown: true
    // How far the sheet reaches, the 50 it hides in the border included.
    property real extent: shown && stack.height > 0 ? stack.height + 50 : 0

    // As wide as a row even while the last one leaves, so the sheet doesn't narrow.
    width: Math.round(340 * Config.scale)
    height: Math.max(0, extent - 50)
    clip: true
    enabled: shown

    Behavior on extent {
        Anim {}
    }

    HoverHandler {
        id: hover
    }

    Column {
        id: stack
        width: parent.width
        spacing: 0

        add: Transition {
            Anim { property: "opacity"; from: 0; to: 1; effects: true }
        }

        move: Transition {
            Anim { property: "y" }
        }

        Repeater {
            model: ScriptModel {
                values: toasts.active ? Notifs.toasts : []
            }

            Toast {}
        }
    }
}
