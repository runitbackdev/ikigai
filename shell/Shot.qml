import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Print. An overlay per screen maps transparent with a blank cursor, every screen is
// captured (cosmic-comp paints the pointer into captures whatever grim asks, so it has
// to be hidden first), then the frozen capture fades in with a pill to pick what to
// capture (a region, a screen) and what to do with it (snip: clipboard +
// ~/Pictures/Screenshots; edit: satty; text: tesseract, to the clipboard). Freezing
// keeps the screen from changing under the drag. Color is a fourth mode: a loupe over
// the frozen capture, a click puts the pixel's hex on the clipboard.
Scope {
    id: shot

    property bool open: false
    property bool frozen: false
    property bool closing: false
    property bool flashing: false
    property string mode: "region"
    property int focused: 0
    property bool everFocused: false
    property string action: "snip"
    property string stamp: ""
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/ikigai/shot"

    readonly property var modes: [
        { id: "region", icon: "selection", label: "Region", key: Qt.Key_1 },
        { id: "window", icon: "app-window", label: "Window", key: Qt.Key_2 },
        { id: "screen", icon: "monitor", label: "Screen", key: Qt.Key_3 },
        { id: "color", icon: "eyedropper", label: "Color", key: Qt.Key_4 }
    ]
    readonly property var actions: [
        { id: "snip", icon: "copy", label: "Snip" },
        { id: "edit", icon: "pencil-simple", label: "Edit" },
        { id: "text", icon: "text-aa", label: "Text" },
        { id: "record", icon: "record", label: "Record" }
    ]

    IpcHandler {
        target: "shot"

        function region(): void { shot.begin("region", "snip"); }
        function window(): void { shot.begin("window", "snip"); }
        function screen(): void { shot.begin("screen", "snip"); }
        function text(): void { shot.begin("region", "text"); }
        function color(): void { shot.begin("color", "snip"); }
        function record(): void {
            if (Recorder.recording)
                Recorder.stop();
            else
                shot.begin("region", "record");
        }
    }

    function begin(mode, action) {
        if (open)
            return;
        shot.mode = mode;
        shot.action = action;
        stamp = Date.now().toString();
        frozen = false;
        focused = 0;
        everFocused = false;
        open = true;
        Bridge.requestGeometry();
        settle.restart();
    }

    // Focus moving between our own overlays arrives as a leave then an enter; let the
    // pair land before deciding the shot lost the screen.
    Timer {
        id: settleFocus
        interval: 50
        onTriggered: {
            if (shot.open && shot.everFocused && shot.focused <= 0)
                shot.cancel();
        }
    }

    // A couple of frames for the overlays to map and the pointer to pick up the blank cursor.
    Timer {
        id: settle
        interval: 80
        onTriggered: {
            freeze.command = ["sh", "-c", 'rm -rf "$0" && mkdir -p "$0" && for o; do grim -o "$o" "$0/$o.png" || exit 1; done', shot.dir, ...Quickshell.screens.map(s => s.name)];
            freeze.running = true;
        }
    }

    Process {
        id: freeze
        onExited: (code, status) => {
            if (code === 0) {
                shot.frozen = true;
            } else {
                console.warn("shot: capture failed", code);
                shot.cancel();
            }
        }
    }

    // A toast of our own, through the notification server like anyone else's.
    function notify(summary, body) {
        Quickshell.execDetached(["busctl", "--user", "--", "call", "org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "Notify", "susssasa{sv}i", "Ikigai", "0", "", summary, body, "0", "0", "4000"]);
    }

    // The pixel under the pointer, as hex, onto the clipboard.
    function commitColor(hex) {
        if (!frozen || closing || flashing)
            return;
        console.info("shot color", hex);
        Apps.spawn(["sh", "-c", 'printf %s "$0" | wl-copy', hex]);
        notify("Copied " + hex, "");
        flashing = true;
        flash.restart();
    }

    // The overlay must be gone before the recorder starts, or it is in the recording.
    property var pendingRecord: null

    function commit(window, rect) {
        if (!frozen || closing || flashing)
            return;
        if (shot.action === "record") {
            console.info("shot record", window.screen.name, window.wholeScreen ? "whole" : rect.width + "x" + rect.height);
            // Plain numbers: a rect read off the window is a reference that dies with it.
            pendingRecord = { screen: window.screen, rect: window.wholeScreen ? null : { x: rect.x, y: rect.y, width: rect.width, height: rect.height } };
            dismiss();
            return;
        }
        const path = dir + "/shot-" + stamp + ".png";
        const dpr = window.screen.devicePixelRatio;
        const action = shot.action;
        console.info("shot", action, window.screen.name, rect.width + "x" + rect.height);
        window.crop.grabToImage(result => {
            if (!result.saveToFile(path)) {
                console.warn("shot: could not write", path);
                return;
            }
            if (action === "edit")
                Apps.spawn(["satty", "--filename", path]);
            else if (action === "text")
                Apps.spawn(["sh", "-c", 'ikigai-shot ocr "$0"', path]);
            else
                Apps.spawn(["sh", "-c", 'ikigai-shot keep "$0"', path]);
        }, Qt.size(Math.round(rect.width * dpr), Math.round(rect.height * dpr)));
        if (action === "snip" || action === "text") {
            flashing = true;
            flash.restart();
        } else {
            dismiss();
        }
    }

    function cancel() {
        if (closing)
            return;
        console.info("shot cancel");
        if (frozen)
            dismiss();
        else
            open = false;
    }

    function dismiss() {
        if (!open)
            return;
        closing = true;
        fade.restart();
    }

    Timer {
        id: flash
        interval: 220
        onTriggered: {
            shot.flashing = false;
            shot.dismiss();
        }
    }

    Timer {
        id: fade
        interval: Motion.fastEffects
        onTriggered: {
            shot.open = false;
            shot.closing = false;
            if (shot.pendingRecord)
                arm.restart();
        }
    }

    Timer {
        id: arm
        interval: 100
        onTriggered: {
            Recorder.start(shot.pendingRecord.screen, shot.pendingRecord.rect);
            shot.pendingRecord = null;
        }
    }

    component PillButton: Item {
        id: button

        property string icon
        property string label
        property bool checked: false

        signal clicked

        implicitWidth: row.implicitWidth + 20
        implicitHeight: Math.round(30 * Config.scale)

        StateLayer {
            radius: height / 2
            hovered: hover.hovered
            pressed: press.pressed
            active: button.checked
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Glyph {
                name: button.icon
                size: Theme.iconSize - 2
                fill: button.checked
                color: button.checked ? Theme.colors.primary : Theme.colors.fg
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: button.label
                color: button.checked ? Theme.colors.primary : Theme.colors.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            id: press
            anchors.fill: parent
            onClicked: button.clicked()
        }
    }

    Variants {
        model: shot.open ? Quickshell.screens : []

        PanelWindow {
            id: window

            required property var modelData
            readonly property alias crop: crop
            property rect selection: Qt.rect(0, 0, 0, 0)
            property point anchor
            property bool dragging: false

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: shot.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:shot"
            color: "transparent"

            readonly property string frozen: shot.frozen ? "file://" + shot.dir + "/" + modelData.name + ".png" : ""
            readonly property bool picking: shot.mode === "color" && hover.hovered
            readonly property bool wholeScreen: shot.mode === "screen" && hover.hovered
            readonly property var target: shot.mode === "window" && hover.hovered ? windowUnder(hover.point.position) : null
            readonly property rect shown: wholeScreen ? Qt.rect(0, 0, content.width, content.height) : target ? target.rect : selection
            readonly property bool selecting: shown.width > 0 && shown.height > 0

            // Windows on this output's active workspace, most recently active first: the
            // best stand-in for stacking order, which nothing on the wire carries.
            readonly property var candidates: {
                const active = Bridge.workspaces.filter(w => w.active && w.outputs.includes(modelData.name)).map(w => w.id);
                return Bridge.geometry
                    .filter(g => g.output === modelData.name)
                    .map(g => ({ g: g, w: Bridge.windows.find(w => w.id === g.id) }))
                    .filter(x => x.w && !x.w.states.includes("minimized") && x.w.workspaces.some(id => active.includes(id)))
                    .sort((a, b) => b.w.lastActive - a.w.lastActive)
                    .map(x => ({ id: x.g.id, title: x.w.title, rect: Qt.rect(
                        Math.max(0, x.g.x), Math.max(0, x.g.y),
                        Math.min(x.g.x + x.g.width, content.width) - Math.max(0, x.g.x),
                        Math.min(x.g.y + x.g.height, content.height) - Math.max(0, x.g.y)) }));
            }

            function windowUnder(p) {
                return candidates.find(c => p.x >= c.rect.x && p.x < c.rect.x + c.rect.width && p.y >= c.rect.y && p.y < c.rect.y + c.rect.height) || null;
            }

            function setMode(mode) {
                shot.mode = mode;
                selection = Qt.rect(0, 0, 0, 0);
            }

            Item {
                id: content
                anchors.fill: parent
                focus: true
                opacity: shot.frozen && !shot.closing ? 1 : 0

                Behavior on opacity {
                    Anim { effects: true; fast: true }
                }

                // Losing focus to something else (a launcher, a lock) abandons the shot,
                // but only once every overlay has lost it: clicking one output hands
                // keyboard focus to that overlay and takes it off its sibling, and our
                // own overlay is not someone else.
                readonly property bool active: Window.active
                onActiveChanged: {
                    if (active) {
                        shot.focused++;
                        shot.everFocused = true;
                    } else {
                        shot.focused--;
                        settleFocus.restart();
                    }
                }

                Keys.onPressed: event => {
                    const mode = shot.modes.find(m => m.key === event.key);
                    if (mode) {
                        window.setMode(mode.id);
                        event.accepted = true;
                        return;
                    }
                    switch (event.key) {
                    case Qt.Key_Escape: shot.cancel(); break;
                    case Qt.Key_Tab: {
                        if (shot.mode === "color")
                            break;
                        const i = shot.actions.findIndex(a => a.id === shot.action);
                        shot.action = shot.actions[(i + 1) % shot.actions.length].id;
                        break;
                    }
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (window.picking)
                            shot.commitColor(loupe.hex);
                        else if (window.selecting)
                            shot.commit(window, window.shown);
                        break;
                    default: return;
                    }
                    event.accepted = true;
                }

                HoverHandler {
                    id: hover
                }

                // The frozen capture, painted once into a canvas as well so a pixel can
                // be read back for the color pick.
                Canvas {
                    id: sampler
                    anchors.fill: parent
                    z: -1
                    renderTarget: Canvas.Image
                    renderStrategy: Canvas.Immediate
                    canvasSize: Qt.size(Math.round(content.width * window.screen.devicePixelRatio), Math.round(content.height * window.screen.devicePixelRatio))
                    property bool ready: false
                    onImageLoaded: {
                        const ctx = getContext("2d");
                        ctx.drawImage(window.frozen, 0, 0, canvasSize.width, canvasSize.height);
                        ready = true;
                    }
                    Component.onCompleted: if (window.frozen) loadImage(window.frozen)
                    Connections {
                        target: window
                        function onFrozenChanged() {
                            if (window.frozen)
                                sampler.loadImage(window.frozen);
                        }
                    }
                    function pixel(p) {
                        if (!ready)
                            return "#000000";
                        const dpr = window.screen.devicePixelRatio;
                        const d = getContext("2d").getImageData(Math.min(canvasSize.width - 1, Math.floor(p.x * dpr)), Math.min(canvasSize.height - 1, Math.floor(p.y * dpr)), 1, 1).data;
                        const hex = n => (n < 16 ? "0" : "") + n.toString(16);
                        return "#" + hex(d[0]) + hex(d[1]) + hex(d[2]);
                    }
                }

                Image {
                    id: frozenImage
                    anchors.fill: parent
                    source: window.frozen
                    cache: false
                    fillMode: Image.Stretch
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(Theme.colors.surface, window.picking ? 0.15 : 0.6)

                    Behavior on color {
                        ColorAnim { fast: true }
                    }
                }

                // The loupe: sixteen pixels across, magnified, the middle one outlined,
                // its hex underneath.
                Item {
                    id: loupe
                    readonly property point at: hover.point.position
                    readonly property string hex: window.picking ? sampler.pixel(at) : "#000000"
                    readonly property int size: Math.round(128 * Config.scale)
                    visible: window.picking && !shot.flashing
                    x: Math.min(at.x + 24, content.width - width - 8)
                    y: Math.min(at.y + 24, content.height - height - 8)
                    width: size
                    height: size + Math.round(30 * Config.scale)

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Theme.colors.surfaceContainer
                        border.width: 1
                        border.color: Theme.colors.outlineVariant
                    }

                    Item {
                        x: 4
                        y: 4
                        width: loupe.size - 8
                        height: loupe.size - 8
                        clip: true

                        ShaderEffectSource {
                            anchors.fill: parent
                            sourceItem: frozenImage
                            sourceRect: Qt.rect(loupe.at.x - 8, loupe.at.y - 8, 16, 16)
                            smooth: false
                            // Sixteen pixels a frame: cheap, and the rect moves with the pointer.
                            live: true
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width / 16
                            height: width
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.colors.fg
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: loupe.size + 2
                        spacing: 6

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 3
                            color: loupe.hex
                            border.width: 1
                            border.color: Theme.colors.outlineVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: loupe.hex
                            color: Theme.colors.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // The undimmed selection: a clipped view of the frozen capture, and what
                // gets grabbed at physical size for the crop.
                Item {
                    id: crop
                    x: window.shown.x
                    y: window.shown.y
                    width: window.shown.width
                    height: window.shown.height
                    clip: true
                    visible: window.selecting

                    Image {
                        x: -crop.x
                        y: -crop.y
                        width: content.width
                        height: content.height
                        source: window.frozen
                        cache: false
                        fillMode: Image.Stretch
                    }
                }

                Rectangle {
                    readonly property int weight: shot.flashing ? 4 : 2
                    x: crop.x - weight
                    y: crop.y - weight
                    width: crop.width + 2 * weight
                    height: crop.height + 2 * weight
                    visible: window.selecting
                    color: "transparent"
                    border.width: weight
                    border.color: shot.flashing ? Theme.colors.fg : shot.action === "record" ? Theme.colors.error : Theme.colors.primary
                    radius: weight

                    Behavior on border.color {
                        ColorAnim {}
                    }
                }

                Rectangle {
                    visible: window.selecting && !window.wholeScreen
                    x: Math.min(crop.x + crop.width + 8, content.width - width - 8)
                    y: Math.min(crop.y + crop.height + 8, content.height - height - 8)
                    width: size.implicitWidth + 16
                    height: size.implicitHeight + 8
                    radius: height / 2
                    color: Theme.colors.surfaceContainerHigh

                    Text {
                        id: size
                        anchors.centerIn: parent
                        text: window.target ? window.target.title : Math.round(window.shown.width * window.screen.devicePixelRatio) + " × " + Math.round(window.shown.height * window.screen.devicePixelRatio)
                        color: Theme.colors.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: !shot.frozen ? Qt.BlankCursor : shot.mode === "region" || shot.mode === "color" ? Qt.CrossCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            shot.cancel();
                            return;
                        }
                        if (shot.mode === "color" && shot.frozen) {
                            shot.commitColor(sampler.pixel(Qt.point(mouse.x, mouse.y)));
                            return;
                        }
                        if (shot.mode !== "region" || !shot.frozen)
                            return;
                        window.dragging = true;
                        window.anchor = Qt.point(mouse.x, mouse.y);
                        window.selection = Qt.rect(mouse.x, mouse.y, 0, 0);
                    }
                    onPositionChanged: mouse => {
                        if (!window.dragging)
                            return;
                        const x = Math.max(0, Math.min(mouse.x, content.width));
                        const y = Math.max(0, Math.min(mouse.y, content.height));
                        window.selection = Qt.rect(Math.min(x, window.anchor.x), Math.min(y, window.anchor.y), Math.abs(x - window.anchor.x), Math.abs(y - window.anchor.y));
                    }
                    onReleased: mouse => {
                        if (mouse.button !== Qt.LeftButton)
                            return;
                        window.dragging = false;
                        if (window.selecting)
                            shot.commit(window, window.shown);
                        else
                            window.selection = Qt.rect(0, 0, 0, 0);
                    }
                }

                // What to capture, and what to do with it.
                Rectangle {
                    id: pill
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(24 * Config.scale)
                    width: groups.implicitWidth + 12
                    height: groups.implicitHeight + 12
                    radius: height / 2
                    color: Theme.colors.surfaceContainer
                    border.width: 1
                    border.color: Theme.colors.outlineVariant
                    opacity: window.dragging || shot.flashing ? 0.25 : 1

                    Behavior on opacity {
                        Anim { effects: true; fast: true }
                    }

                    Row {
                        id: groups
                        anchors.centerIn: parent
                        spacing: 8

                        Row {
                            spacing: 2

                            Repeater {
                                model: shot.modes

                                PillButton {
                                    required property var modelData
                                    icon: modelData.icon
                                    label: modelData.label
                                    checked: shot.mode === modelData.id
                                    onClicked: window.setMode(modelData.id)
                                }
                            }
                        }

                        Rectangle {
                            visible: shot.mode !== "color"
                            width: 1
                            height: Math.round(18 * Config.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.colors.outlineVariant
                        }

                        Row {
                            visible: shot.mode !== "color"
                            spacing: 2

                            Repeater {
                                model: shot.actions

                                PillButton {
                                    required property var modelData
                                    icon: modelData.icon
                                    label: modelData.label
                                    checked: shot.action === modelData.id
                                    onClicked: shot.action = modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
