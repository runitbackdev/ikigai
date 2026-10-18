import QtQuick

// A line in a card that opens and closes instead of popping: it fades while its height
// follows, so what sits below slides rather than jumps. `gap` is the room above it, kept
// here rather than in the column's spacing so a closed line takes none at all. The host
// holds the content through the close, or it empties as it goes.
Item {
    id: reveal

    property bool shown: false
    property real gap: 0
    default property alias content: inner.data

    implicitHeight: shown ? gap + inner.childrenRect.height : 0
    height: implicitHeight
    opacity: shown ? 1 : 0
    visible: height > 0
    clip: true

    Behavior on height {
        Anim { standard: true }
    }

    Behavior on opacity {
        Anim { effects: true }
    }

    Item {
        id: inner
        y: reveal.gap
        width: reveal.width
    }
}
