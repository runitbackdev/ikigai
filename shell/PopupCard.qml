import QtQuick

// Content of a popout. Sized by implicitWidth/Height; Popouts fits its frame to whichever
// content is current and cross-fades between them. `done` asks the host to close.
Item {
    id: card

    property var task: null
    property bool shown: false
    // Up, fading, or still in the host's frame as it tucks away: anything costly to keep
    // current can idle otherwise, and must not change the card's size before then.
    readonly property bool live: shown || opacity > 0 || (!!parent && parent.held === card)
    default property alias content: body.data
    // What the card's own blob covers, and further panels beside it (a menu's open
    // submenus), in the card's coordinates. By default the whole card and nothing else.
    property real baseWidth: implicitWidth
    property real baseHeight: implicitHeight
    property var panels: []

    signal done

    width: implicitWidth
    height: implicitHeight
    // Centred on the frame's height through a morph, so it crops the old and new cards
    // evenly and the new one waits in place for the frame to reach it. Settled, on the
    // frame's top edge, which eases as the card grows. Left-aligned: it hangs off the rail.
    y: !parent || parent.settled === card ? 0 : Math.round((parent.height - height) / 2)
    opacity: 0
    visible: opacity > 0

    Item {
        id: body
        anchors {
            fill: parent
            margins: 6
        }
    }

    // The incoming card fades in slower than the outgoing one leaves, so the two don't
    // sit on top of each other at half strength while the frame morphs.
    states: State {
        name: "shown"
        when: card.shown
        PropertyChanges {
            target: card
            opacity: 1
        }
    }

    transitions: [
        Transition {
            to: "shown"
            Anim { property: "opacity"; effects: true; slow: true }
        },
        Transition {
            from: "shown"
            Anim { property: "opacity"; effects: true }
        }
    ]
}
