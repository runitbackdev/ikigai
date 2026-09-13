import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Ikigai.Input
import QtQuick
import QtQuick.Effects

// Alt+Tab. cosmic-comp runs `ikigai-shell switcher next` on every Tab press while Alt is
// held; the overlay takes exclusive keyboard focus when it maps, so the Alt release lands
// here and commits. The list is frozen while open, most recent first, like Windows. It
// opens on the primary screen, also like Windows: its Alt+Tab is on the primary display
// whichever monitor the active window or the mouse is on, so it is always in the same place.
Scope {
    id: switcher

    property bool open: false
    property var order: []
    property int index: 0
    // Frozen at open, so an output dropping off mid-cycle does not move the card.
    property var screen: null

    IpcHandler {
        target: "switcher"

        function next(): void { switcher.step(1); }
        function prev(): void { switcher.step(-1); }
    }

    function step(by) {
        if (!open) {
            const windows = Bridge.windows.map((w, i) => ({ w: w, i: i }));
            order = windows.sort((a, b) => b.w.lastActive - a.w.lastActive || a.i - b.i).map(x => x.w);
            if (order.length === 0)
                return;
            index = 0;
            screen = Screens.primary;
            open = true;
            Bridge.capture(order.map(w => w.id));
        }
        index = (index + by + order.length) % order.length;
    }

    // While the overlay holds exclusive keyboard focus cosmic-comp re-validates any other
    // focus against it, so the claim is dropped first and the window activated once the
    // compositor has seen that; the card fades out over the same gap.
    property string pending: ""
    property bool closing: false

    function commit(i) {
        if (closing)
            return;
        pending = open && order[i] ? order[i].id : "";
        console.info("switcher commit", i, order[i] ? order[i].title : "-");
        dismiss();
    }

    // Closing a window from the switcher leaves it open; the closed event drops the entry.
    function close(i) {
        if (open && !closing && order[i])
            Bridge.close(order[i].id);
    }

    function cancel() {
        if (closing)
            return;
        pending = "";
        console.info("switcher cancel");
        dismiss();
    }

    function dismiss() {
        if (!open)
            return;
        closing = true;
        handoff.restart();
        fade.restart();
    }

    Timer {
        id: handoff
        interval: 50
        onTriggered: {
            if (switcher.pending)
                Bridge.activate(switcher.pending);
            switcher.pending = "";
        }
    }

    Timer {
        id: fade
        interval: Motion.fastEffects
        onTriggered: {
            switcher.open = false;
            switcher.closing = false;
        }
    }

    // Windows closed while the switcher is open drop out of the list.
    Connections {
        target: Bridge

        function onWindowsChanged() {
            if (!switcher.open)
                return;
            const live = switcher.order.filter(w => Bridge.windows.some(x => x.id === w.id));
            if (live.length === 0) {
                switcher.cancel();
            } else if (live.length !== switcher.order.length) {
                switcher.index = Math.min(switcher.index, live.length - 1);
                switcher.order = live;
            }
        }
    }

    LazyLoader {
        active: switcher.open

        PanelWindow {
            id: window
            screen: switcher.screen

            readonly property int shadowRoom: 24
            readonly property int tileWidth: Math.round(216 * Config.scale)
            readonly property int gap: Math.round(8 * Config.scale)
            readonly property int pad: Math.round(16 * Config.scale)

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: switcher.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:switcher"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            implicitWidth: card.width + 2 * shadowRoom
            implicitHeight: card.height + 2 * shadowRoom

            Item {
                id: keys
                anchors.fill: parent
                focus: true

                readonly property bool active: Window.active

                // A quick tap releases Alt before the overlay exists, so that release never
                // arrives: on gaining focus, commit at once unless a modifier is still held.
                // Losing focus means nothing: the overlay is exclusive, so only a lock can
                // keep focus from it, and cosmic-comp hands focus to any window that asks
                // (a late activate, an app raising itself) for one frame before taking it
                // back. The release that landed elsewhere is caught the same way on return.
                onActiveChanged: {
                    if (active)
                        Qt.callLater(keys.commitUnlessHeld);
                }

                function commitUnlessHeld() {
                    if (switcher.open && !(Keyboard.modifiers() & (Qt.AltModifier | Qt.MetaModifier)))
                        switcher.commit(switcher.index);
                }

                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)
                        switcher.commit(switcher.index);
                }
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape: switcher.cancel(); break;
                    case Qt.Key_Left: switcher.step(-1); break;
                    case Qt.Key_Right: switcher.step(1); break;
                    case Qt.Key_Delete: switcher.close(switcher.index); break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space: switcher.commit(switcher.index); break;
                    default: return;
                    }
                    event.accepted = true;
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: grid.width + 2 * window.pad
                height: grid.height + 2 * window.pad
                property bool shown: false

                radius: Theme.cardRadius
                color: Theme.colors.surface
                opacity: shown && !switcher.closing ? 1 : 0
                scale: shown && !switcher.closing ? 1 : 0.96
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha("black", 0.6)
                }

                Component.onCompleted: shown = true

                Behavior on opacity {
                    Anim { effects: true }
                }

                Behavior on scale {
                    Anim {}
                }

                Grid {
                    id: grid
                    x: window.pad
                    y: window.pad
                    columns: Math.max(1, Math.floor((window.screen.width - 160) / (window.tileWidth + window.gap)))
                    spacing: window.gap

                    Repeater {
                        model: ScriptModel {
                            values: switcher.order
                            objectProp: "id"
                        }

                        WindowTile {
                            required property var modelData
                            required property int index

                            entry: modelData
                            selected: index === switcher.index
                            width: window.tileWidth
                            closable: true
                            onClicked: switcher.commit(index)
                            onCloseRequested: switcher.close(index)
                        }
                    }
                }
            }
        }
    }
}
