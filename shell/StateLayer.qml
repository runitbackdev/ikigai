import QtQuick

// Interaction tint over a control, in its rounded shape: faint on hover, stronger while
// active, strongest while pressed. The button itself scales on press; this only paints.
Rectangle {
    id: layer

    property bool hovered: false
    property bool pressed: false
    property bool active: false

    anchors.fill: parent
    radius: Theme.radius
    color: Theme.colors.fg
    opacity: 0

    // A press has to land at once to read as feedback; hover and release ease. States,
    // not a Behavior keyed on `pressed`: the duration would be read before or after the
    // retarget depending on binding order, so a press could take the release's timing.
    states: [
        State {
            name: "pressed"
            when: layer.pressed
            PropertyChanges { target: layer; opacity: 0.16 }
        },
        State {
            name: "active"
            when: layer.active
            PropertyChanges { target: layer; opacity: 0.12 }
        },
        State {
            name: "hovered"
            when: layer.hovered
            PropertyChanges { target: layer; opacity: 0.08 }
        }
    ]

    transitions: [
        Transition {
            to: "pressed"
            Anim { property: "opacity"; effects: true; fast: true }
        },
        Transition {
            Anim { property: "opacity"; effects: true }
        }
    ]
}
