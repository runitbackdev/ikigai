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
    // The last minute, oldest first, each 0..1: the CPU, each core, memory in use, and
    // each GPU by its bus id with its memory.
    property var history: monitor.emptyHistory()
    readonly property int keep: 60
    property string error: ""

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
            error = "";
        }
    }

    onPageChanged: request({ request: "interval", ms: page === "performance" ? 500 : 1000 })

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
        running: monitor.open
        command: ["ikigai-monitor"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => monitor.handle(line)
        }
        stderr: SplitParser {
            onRead: line => console.warn("monitor:", line)
        }
        onStarted: monitor.request({ request: "interval", ms: monitor.page === "performance" ? 500 : 1000 })
        onExited: (code, status) => {
            if (monitor.open && !monitor.error)
                monitor.error = "ikigai-monitor exited with " + code;
        }
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
        if (d.event === "error") {
            error = d.message;
            return;
        }
        if (d.event !== "sample")
            return;
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
                Anim { effects: true; fast: true }
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

                        Text {
                            id: tabLabel
                            anchors {
                                left: tabGlyph.right
                                leftMargin: Math.round(8 * Config.scale)
                                verticalCenter: parent.verticalCenter
                            }
                            text: tab.modelData.label
                            color: tab.current ? Theme.colors.fg : Theme.colors.fgVariant
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
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

            // Before the first sample, or after the feed died.
            Text {
                anchors.centerIn: parent
                visible: monitor.sample === null
                text: monitor.error ? monitor.error : "Reading…"
                color: monitor.error ? Theme.colors.error : Theme.colors.fgVariant
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
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
                visible: monitor.sample !== null

                MonitorProcesses {
                    anchors.fill: parent
                    visible: monitor.page === "processes"
                    focus: visible
                    sample: monitor.sample
                    onTerminate: pids => monitor.terminate(pids)
                    onKill: pids => monitor.kill(pids)
                }

                MonitorPerformance {
                    anchors.fill: parent
                    visible: monitor.page === "performance"
                    focus: visible
                    sample: monitor.sample
                    history: monitor.history
                }
            }
        }
    }
}
