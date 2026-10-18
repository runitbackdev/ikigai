import QtQuick
import QtQuick.Effects

// The card the dialogs, the lock and the greeter share: it fades and grows in on its
// window's first frame and back out when `shown` goes false. The shadow is drawn from a
// plain background beside the content rather than around it, so a keystroke or the
// cursor's blink redraws the text, not the whole card through an offscreen blur.
Item {
    id: card

    property bool shown: true
    property int pad: Math.round(28 * Config.scale)
    default property alias content: body.data

    property bool entered: false
    readonly property bool showing: entered && shown

    implicitWidth: body.childrenRect.width + 2 * pad
    implicitHeight: body.childrenRect.height + 2 * pad
    opacity: showing ? 1 : 0
    scale: showing ? 1 : 0.96

    Behavior on opacity {
        Anim { effects: true }
    }

    Behavior on scale {
        Anim {}
    }

    // Windows here are made on demand; started at creation the entry ran before the
    // compositor showed a frame. The timer is for a window that never swaps one: on the
    // lock an invisible card would leave a field nobody can see.
    Connections {
        target: card.Window.window
        enabled: !card.entered

        function onFrameSwapped() {
            card.entered = true;
        }
    }

    Timer {
        interval: 250
        running: !card.entered
        onTriggered: card.entered = true
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Theme.colors.surface
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha("black", 0.6)
        }
    }

    // A click on the card stays on it rather than reaching the dim's dismiss behind.
    MouseArea {
        anchors.fill: parent
    }

    Item {
        id: body
        x: card.pad
        y: card.pad
    }
}
