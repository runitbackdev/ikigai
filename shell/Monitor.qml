import Quickshell
import Quickshell.Io
import QtQuick

// The task manager: a Drop on the focused screen with two pages, Processes (apps and
// their processes, what each uses, End task) and Performance (CPU, memory and GPU graphs
// over the last minute). The numbers come from `ikigai-monitor`, which runs Mission
// Center's data daemon for as long as the card is up and prints a sample a second; the
// card asks it for a faster tick while Performance is showing.
// `ikigai-shell monitor open|close|toggle`, Ctrl+Shift+Escape's binding.
Scope {
    id: monitor

    property bool open: false
    property string page: "processes"
    // The latest sample as ikigai-monitor prints it (monitor/src/sample.rs); null before
    // the first, which arrives about a second after opening.
    property var sample: null
    // The last minute, oldest first, a point a second, each 0..1: the CPU, each core,
    // memory in use, and each GPU by its bus id with its memory.
    property var history: monitor.emptyHistory()
    // One past the graphs' 60: the extra is the oldest, sliding off their left edge.
    readonly property int keep: 61
    // The graphs' step. A point a second whatever the tick, so the 60 across a graph are
    // a minute on either page and a page flip doesn't mix two spacings in one curve.
    readonly property int step: 1000
    // The tick's time since the last point went in.
    property int due: 0
    property string error: ""
    // How often the feed samples: faster while Performance's numbers are showing.
    readonly property int interval: page === "performance" ? 500 : 1000
    // Off from the feed dying until `respawn` brings it back.
    property bool alive: true

    function emptyHistory() {
        return { cpu: [], cores: [], memory: [], gpus: {}, gpuMemory: {} };
    }

    function toggle() {
        open = !open;
    }

    onOpenChanged: {
        console.info("monitor", open ? "open" : "close");
        if (open) {
            sample = null;
            history = emptyHistory();
            due = 0;
            error = "";
            alive = true;
        }
    }

    onIntervalChanged: request({ request: "interval", ms: interval })

    IpcHandler {
        target: "monitor"

        function open(): void { monitor.open = true; }
        function close(): void { monitor.open = false; }
        function toggle(): void { monitor.toggle(); }
        // Open on a page.
        function processes(): void {
            monitor.page = "processes";
            monitor.open = true;
        }
        function performance(): void {
            monitor.page = "performance";
            monitor.open = true;
        }
    }

    Process {
        id: feed
        running: monitor.open && monitor.alive
        command: ["ikigai-monitor"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => monitor.handle(line)
        }
        stderr: SplitParser {
            onRead: line => console.warn("monitor:", line)
        }
        onStarted: monitor.request({ request: "interval", ms: monitor.interval })
        // Started again after a pause while the card is up; the last sample stays on
        // screen under the error until the new feed's first replaces it.
        onExited: (code, status) => {
            if (!monitor.open)
                return;
            monitor.error = "ikigai-monitor exited with " + code + ", restarting";
            monitor.alive = false;
            respawn.restart();
        }
    }

    Timer {
        id: respawn
        interval: 2000
        onTriggered: monitor.alive = true
    }

    function request(r) {
        if (feed.running)
            feed.write(JSON.stringify(r) + "\n");
    }

    function terminate(pids) {
        console.info("monitor terminate", pids.join(" "));
        request({ request: "terminate", pids: pids });
    }

    function kill(pids) {
        console.info("monitor kill", pids.join(" "));
        request({ request: "kill", pids: pids });
    }

    function push(list, v) {
        list.push(v);
        if (list.length > keep)
            list.shift();
        return list;
    }

    function handle(line) {
        let d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            console.warn("monitor: bad line", line.slice(0, 80));
            return;
        }
        // The feed carries on after an error event, so a sample clears it again.
        if (d.event === "error") {
            error = d.message;
            return;
        }
        if (d.event !== "sample")
            return;
        error = "";
        due += interval;
        if (sample !== null && due < step) {
            sample = d;
            return;
        }
        due = 0;
        const h = history;
        push(h.cpu, d.cpu.usage / 100);
        d.cpu.cores.forEach((c, i) => {
            if (!h.cores[i])
                h.cores[i] = [];
            push(h.cores[i], c / 100);
        });
        push(h.memory, d.memory.total ? d.memory.used / d.memory.total : 0);
        for (const g of d.gpus) {
            if (!h.gpus[g.id]) {
                h.gpus[g.id] = [];
                h.gpuMemory[g.id] = [];
            }
            push(h.gpus[g.id], (g.usage || 0) / 100);
            push(h.gpuMemory[g.id], g.memTotal ? (g.memUsed || 0) / g.memTotal : 0);
        }
        // Fresh arrays, so a Graph bound to one sees a change and repaints.
        const copy = o => {
            const out = {};
            for (const k in o)
                out[k] = o[k].slice();
            return out;
        };
        history = { cpu: h.cpu.slice(), cores: h.cores.map(c => c.slice()), memory: h.memory.slice(), gpus: copy(h.gpus), gpuMemory: copy(h.gpuMemory) };
        sample = d;
    }

    Drop {
        id: drop
        open: monitor.open
        cardWidth: Math.round(1000 * Config.scale)
        cardHeight: Math.round(660 * Config.scale)
        namespace: "ikigai:monitor"
        onDismiss: monitor.open = false

        FocusScope {
            id: card
            anchors.fill: parent
            focus: true
            opacity: drop.landed ? 1 : 0

            readonly property int pad: Math.round(20 * Config.scale)

            Behavior on opacity {
                Anim { effects: true }
            }

            // Ctrl+Tab flips the page, Ctrl+1 and Ctrl+2 pick one.
            Keys.onPressed: event => {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        monitor.page = monitor.page === "processes" ? "performance" : "processes";
                        event.accepted = true;
                    } else if (event.key === Qt.Key_1) {
                        monitor.page = "processes";
                        event.accepted = true;
                    } else if (event.key === Qt.Key_2) {
                        monitor.page = "performance";
                        event.accepted = true;
                    }
                }
            }

            // Tabs, and the title's place taken by them, like Task Manager's rail folded flat.
            Row {
                id: tabs
                x: card.pad
                y: Math.round(16 * Config.scale)
                spacing: Math.round(4 * Config.scale)

                Repeater {
                    model: [
                        { id: "processes", label: "Processes", glyph: "list" },
                        { id: "performance", label: "Performance", glyph: "pulse" }
                    ]

                    Rectangle {
                        id: tab
                        required property var modelData
                        readonly property bool current: monitor.page === modelData.id

                        width: tabLabel.width + tabGlyph.width + Math.round(34 * Config.scale)
                        height: Math.round(36 * Config.scale)
                        radius: height / 2
                        color: current ? Theme.colors.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            ColorAnim {}
                        }

                        Glyph {
                            id: tabGlyph
                            anchors {
                                left: parent.left
                                leftMargin: Math.round(14 * Config.scale)
                                verticalCenter: parent.verticalCenter
                            }
                            name: tab.modelData.glyph
                            size: Math.round(16 * Config.scale)
                            color: tab.current ? Theme.colors.primary : Theme.colors.fgVariant
                        }

                        Words {
                            id: tabLabel
                            anchors {
                                left: tabGlyph.right
                                leftMargin: Math.round(8 * Config.scale)
                                verticalCenter: parent.verticalCenter
                            }
                            text: tab.modelData.label
                            color: tab.current ? Theme.colors.fg : Theme.colors.fgVariant
                            font.weight: tab.current ? Font.DemiBold : Font.Medium
                        }

                        StateLayer {
                            radius: parent.radius
                            hovered: tabHover.hovered && !tab.current
                        }

                        HoverHandler {
                            id: tabHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: monitor.page = tab.modelData.id
                        }
                    }
                }
            }

            // The close cross, where every card puts one.
            Item {
                id: closeButton
                anchors {
                    right: parent.right
                    rightMargin: Math.round(16 * Config.scale)
                    verticalCenter: tabs.verticalCenter
                }
                width: Math.round(32 * Config.scale)
                height: width

                StateLayer {
                    radius: width / 2
                    hovered: closeHover.hovered
                }

                Glyph {
                    anchors.centerIn: parent
                    name: "x"
                    size: Math.round(16 * Config.scale)
                    color: Theme.colors.fgVariant
                }

                HoverHandler {
                    id: closeHover
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: monitor.open = false
                }
            }

            // Before the first sample; it and the body cross-fade as the first sample lands.
            Text {
                anchors.centerIn: parent
                opacity: monitor.sample === null ? 1 : 0
                visible: opacity > 0
                text: monitor.error ? monitor.error : "Reading…"
                color: monitor.error ? Theme.colors.error : Theme.colors.fgVariant
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize

                Behavior on opacity {
                    Anim { effects: true }
                }
            }

            Item {
                id: body
                anchors {
                    left: parent.left
                    right: parent.right
                    top: tabs.bottom
                    bottom: parent.bottom
                    leftMargin: card.pad
                    rightMargin: card.pad
                    topMargin: Math.round(12 * Config.scale)
                    bottomMargin: card.pad
                }
                // Faded rather than hidden before the first sample: a hidden item can't hold
                // focus, so keys typed while it is reading went nowhere.
                opacity: monitor.sample !== null ? 1 : 0

                Behavior on opacity {
                    Anim { effects: true }
                }

                // The pages cross-fade. The incoming one is visible from the start, so it
                // takes focus at once; the outgoing one stays until it has faded.
                MonitorProcesses {
                    readonly property bool current: monitor.page === "processes"
                    anchors.fill: parent
                    opacity: current ? 1 : 0
                    visible: current || opacity > 0
                    // The outgoing page is still on screen but no longer takes the pointer.
                    enabled: current
                    z: current ? 1 : 0
                    focus: current
                    Behavior on opacity {
                        Anim { effects: true }
                    }
                    sample: monitor.sample
                    onTerminate: pids => monitor.terminate(pids)
                    onKill: pids => monitor.kill(pids)
                }

                MonitorPerformance {
                    readonly property bool current: monitor.page === "performance"
                    anchors.fill: parent
                    opacity: current ? 1 : 0
                    visible: current || opacity > 0
                    enabled: current
                    z: current ? 1 : 0
                    focus: current
                    Behavior on opacity {
                        Anim { effects: true }
                    }
                    sample: monitor.sample
                    history: monitor.history
                    // The graphs slide a point at a time, so their pace is the history's.
                    interval: monitor.step
                }
            }

            // An error once samples are showing: the bridge's, or the feed dying. The
            // numbers under it stay until the next sample clears it.
            Rectangle {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: card.pad
                }
                z: 2
                width: errorText.width + Math.round(28 * Config.scale)
                height: Math.round(36 * Config.scale)
                radius: height / 2
                color: Theme.colors.surfaceContainerHigh
                opacity: monitor.error && monitor.sample !== null ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim { effects: true }
                }

                Words {
                    id: errorText
                    anchors.centerIn: parent
                    text: monitor.error
                    color: Theme.colors.error
                }
            }
        }
    }
}
