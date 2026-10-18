import QtQuick

// One card beside the rail that slides to whichever button asked for it and resizes to its
// content, so switching between menus is a morph rather than a close and a reopen. Bar
// masks input to the frame and draws it as a blob; leaving closes it after a grace period.
Item {
    id: popouts

    // The screen this rail sits on: a workspace list is per output.
    property var screen: null
    property Item anchorItem: null
    property bool hovered: false
    property Item current: null
    readonly property bool workspacesOpen: current === workspaces
    readonly property bool volumeOpen: current === volume
    readonly property bool caffeineOpen: current === caffeine
    readonly property bool batteryOpen: current === battery
    readonly property bool networkOpen: current === network
    readonly property bool bluetoothOpen: current === bluetooth
    // 0 with a card out, 1 tucked under the rail: the card unrolls from the rail and its
    // content slides out with the edge, like a drawer.
    property real offset: current ? 0 : 1
    readonly property Item card: frame.width > 0 ? frame : null
    // The card blob's raw deformation; the cards take it about the blob's centre, so the
    // content squashes and stretches with the blob.
    property matrix4x4 deform: Qt.matrix4x4()
    // What to draw, following the moving frame: the card's own blob, which is the frame less
    // whatever the content's panels take beside and below it, and a blob per panel, cut
    // to the frame so a submenu unrolls with it.
    readonly property rect base: card ? Qt.rect(frame.x, frame.y, Math.max(0, frame.width - (frame.content.implicitWidth - frame.content.baseWidth)), Math.max(0, frame.height - (frame.content.implicitHeight - frame.content.baseHeight))) : Qt.rect(0, 0, 0, 0)
    readonly property var panels: card ? frame.trail.filter(p => p).map(p => frame.cut(p)).filter(r => r.width > 0 && r.height > 0) : []

    width: 280

    // Right-clicking the app whose menu is open closes it, like a toggle.
    function openMenu(task, at) {
        if (current === menu && menu.task.appId === task.appId)
            close();
        else
            show(menu, at, task);
    }

    function openWindows(task, at) {
        if (current === menu)
            return;
        if (task.windows.length > 0)
            show(windows, at, task);
        else if (current === windows)
            close();
    }

    function toggleWorkspaces(at) {
        if (current === workspaces)
            close();
        else
            show(workspaces, at, null);
    }

    function openTray(item, at) {
        if (current === tray && tray.task === item)
            close();
        else
            show(tray, at, item);
    }

    function toggleNetwork(at) {
        if (current === network)
            close();
        else
            show(network, at, null);
    }

    function toggleBluetooth(at) {
        if (current === bluetooth)
            close();
        else
            show(bluetooth, at, null);
    }

    function toggleBattery(at) {
        if (current === battery)
            close();
        else
            show(battery, at, null);
    }

    function toggleVolume(at) {
        if (current === volume)
            close();
        else
            show(volume, at, null);
    }

    function toggleCaffeine(at) {
        if (current === caffeine)
            close();
        else
            show(caffeine, at, null);
    }

    function show(content, at, task) {
        content.task = task;
        anchorItem = at;
        current = content;
    }

    function close() {
        current = null;
    }

    onHoveredChanged: hovered ? leave.stop() : leave.restart()

    Timer {
        id: leave
        interval: Motion.grace
        onTriggered: popouts.close()
    }

    Behavior on offset {
        Anim {}
    }

    Item {
        id: frame

        // The content being shown, or the last one while the frame shrinks away.
        property Item content: menu
        property real centre: popouts.anchorItem ? popouts.anchorItem.mapToItem(popouts, 0, popouts.anchorItem.height / 2).y : 0
        // The content's size, eased while a card is out; a fresh card takes its own at once.
        property real fullWidth: content.implicitWidth
        property real fullHeight: content.implicitHeight
        // The content's panels, plus those of submenus just folded, held until the
        // shrinking frame has drawn them back in.
        property var trail: []

        // A panel in the content's coordinates, in ours, inside the frame.
        function cut(p) {
            const left = holder.x + frame.content.x + p.x;
            const top = frame.content.y + p.y;
            const x = Math.max(0, left);
            const y = Math.max(0, top);
            const right = Math.min(frame.width, left + p.width);
            const bottom = Math.min(frame.height, top + p.height);
            return Qt.rect(frame.x + x, frame.y + y, Math.max(0, right - x), Math.max(0, bottom - y));
        }

        function follow() {
            const live = frame.content.panels || [];
            frame.trail = live.concat(frame.trail.slice(live.length));
        }

        // Drop the folded ones once the frame has drawn them all back in.
        function prune() {
            const live = (frame.content.panels || []).length;
            if (frame.trail.length > live && frame.trail.slice(live).every(p => !p || frame.cut(p).width <= 0))
                frame.trail = frame.trail.slice(0, live);
        }

        width: Math.max(0, fullWidth * (1 - popouts.offset))
        height: fullHeight
        y: Math.max(Theme.border, Math.min(popouts.height - Theme.border - height, centre - height / 2))
        // Undeformed, so a stretch can't push the content out over the rail.
        clip: true
        onContentChanged: {
            trail = (content.panels || []).slice();
            // Only a card coming over another one morphs; a fresh one takes its size at once.
            holder.morph = popouts.offset < 1;
            Qt.callLater(() => {
                if (!grow.running)
                    holder.morph = false;
            });
        }
        onWidthChanged: prune()
        onHeightChanged: prune()

        Connections {
            target: frame.content
            function onPanelsChanged() {
                frame.follow();
            }
        }

        Behavior on fullWidth {
            enabled: popouts.offset < 1
            Anim {}
        }

        Behavior on fullHeight {
            enabled: popouts.offset < 1
            Anim {
                id: grow
                onRunningChanged: if (!running) holder.morph = false
            }
        }

        // A fresh card comes out level with its button; only an open one slides to the next.
        Behavior on centre {
            enabled: popouts.offset < 1
            Anim {}
        }

        // The cards, slid back under the rail by however much of the frame is still in.
        Item {
            id: holder

            // The card the frame still shows while it tucks away.
            readonly property Item held: frame.width > 0 ? frame.content : null
            // Easing from one card's height to another's. The cards centre on the frame
            // then; otherwise the current one rides its top edge, so a change in its own
            // height eases with the frame instead of jumping by half of it.
            property bool morph: false
            readonly property Item settled: morph ? null : frame.content

            x: -frame.fullWidth * popouts.offset
            width: frame.fullWidth
            height: frame.height

            // The card blob's matrix, about the blob's centre: it runs from a fifth of its
            // width under the rail (Bar's `under`) to the card's right edge. Submenus take
            // it too; their own blobs' matrices aren't handed over.
            transform: Matrix4x4 {
                matrix: {
                    const m = popouts.deform;
                    const cx = popouts.base.width * 0.4 - holder.x;
                    const cy = popouts.base.height / 2;
                    return Qt.matrix4x4(m.m11, m.m12, 0, cx - m.m11 * cx - m.m12 * cy, m.m21, m.m22, 0, cy - m.m21 * cx - m.m22 * cy, 0, 0, 1, 0, 0, 0, 0, 1);
                }
            }

            TaskMenu {
                id: menu
                shown: popouts.current === menu
                onDone: popouts.close()
            }

            TaskWindows {
                id: windows
                shown: popouts.current === windows
                onDone: popouts.close()
            }

            Workspaces {
                id: workspaces
                screen: popouts.screen
                shown: popouts.current === workspaces
                onDone: popouts.close()
            }

            TrayMenu {
                id: tray
                shown: popouts.current === tray
                onDone: popouts.close()
            }

            VolumeCard {
                id: volume
                shown: popouts.current === volume
                onDone: popouts.close()
            }

            BatteryCard {
                id: battery
                shown: popouts.current === battery
                onDone: popouts.close()
            }

            NetworkCard {
                id: network
                shown: popouts.current === network
                onDone: popouts.close()
            }

            BluetoothCard {
                id: bluetooth
                shown: popouts.current === bluetooth
                onDone: popouts.close()
            }

            CaffeineCard {
                id: caffeine
                shown: popouts.current === caffeine
                onDone: popouts.close()
            }
        }
    }

    onCurrentChanged: if (current) frame.content = current
}
