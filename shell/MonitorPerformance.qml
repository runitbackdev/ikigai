import Quickshell
import QtQuick

// The Performance page: a column of devices on the left, each with a minute of its
// utilization, and the chosen one on the right with its graph and its numbers. The CPU
// graph flips between the whole and every logical processor.
FocusScope {
    id: page

    property var sample: null
    property var history: ({ cpu: [], cores: [], memory: [], gpus: {}, gpuMemory: {} })
    property string device: "cpu"
    property bool perCore: false

    readonly property var gpus: sample ? sample.gpus : []
    readonly property var gpu: {
        if (!device.startsWith("gpu:"))
            return null;
        const id = device.slice(4);
        return gpus.find(g => g.id === id) || null;
    }

    readonly property var devices: {
        if (!sample)
            return [];
        const list = [
            { id: "cpu", name: "CPU", value: Units.percent(sample.cpu.usage), sub: Units.ghz(sample.cpu.freqMhz), series: history.cpu },
            { id: "memory", name: "Memory", value: Units.bytes(sample.memory.used), sub: Math.round(sample.memory.total ? sample.memory.used / sample.memory.total * 100 : 0) + "%", series: history.memory }
        ];
        gpus.forEach((g, i) => list.push({
            id: "gpu:" + g.id, name: "GPU " + i, value: Units.percent(g.usage || 0),
            sub: g.memTotal ? Units.bytes(g.memUsed || 0) : "", series: history.gpus[g.id] || []
        }));
        return list;
    }

    readonly property int pad: Math.round(16 * Config.scale)

    Keys.onPressed: event => {
        const ids = devices.map(d => d.id);
        let i = ids.indexOf(device);
        switch (event.key) {
        case Qt.Key_Down: device = ids[Math.min(ids.length - 1, i + 1)] || device; break;
        case Qt.Key_Up: device = ids[Math.max(0, i - 1)] || device; break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (device === "cpu")
                perCore = !perCore;
            break;
        default: return;
        }
        event.accepted = true;
    }

    component Label: Text {
        color: Theme.colors.fgVariant
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize * 0.88
    }

    component Value: Text {
        color: Theme.colors.fg
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        elide: Text.ElideRight
    }

    // One row of the details grid: a label over a value, Task Manager's layout.
    component Stat: Column {
        property string label
        property string value
        width: parent ? parent.cellWidth : 0
        spacing: 2
        visible: value !== ""

        Label { text: parent.label }
        Value {
            text: parent.value
            width: parent.width
            font.pointSize: Theme.fontSize * 1.15
        }
    }

    // The devices.
    Column {
        id: rail
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: Math.round(236 * Config.scale)
        spacing: Math.round(6 * Config.scale)

        Repeater {
            model: ScriptModel {
                values: page.devices
                objectProp: "id"
            }

            Rectangle {
                id: item
                required property var modelData
                readonly property bool current: page.device === modelData.id

                width: rail.width
                height: Math.round(64 * Config.scale)
                radius: Theme.radius
                color: current ? Theme.colors.surfaceContainerHigh : "transparent"

                StateLayer {
                    hovered: itemHover.hovered && !item.current
                }

                Rectangle {
                    id: spark
                    anchors {
                        left: parent.left
                        leftMargin: Math.round(10 * Config.scale)
                        verticalCenter: parent.verticalCenter
                    }
                    width: Math.round(72 * Config.scale)
                    height: Math.round(44 * Config.scale)
                    radius: 4
                    color: Theme.colors.surfaceContainerLow
                    border.width: 1
                    border.color: Qt.alpha(Theme.colors.primary, 0.4)
                    clip: true

                    Graph {
                        anchors.fill: parent
                        anchors.margins: 1
                        values: item.modelData.series
                        grid: false
                        lineWidth: 1
                    }
                }

                Column {
                    anchors {
                        left: spark.right
                        right: parent.right
                        leftMargin: Math.round(12 * Config.scale)
                        rightMargin: Math.round(8 * Config.scale)
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 1

                    Value {
                        text: item.modelData.name
                        width: parent.width
                        font.weight: Font.DemiBold
                    }

                    Label {
                        text: item.modelData.value + (item.modelData.sub ? "  " + item.modelData.sub : "")
                        width: parent.width
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    id: itemHover
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.device = item.modelData.id
                }
            }
        }
    }

    // The chosen device.
    Item {
        id: detail
        anchors {
            left: rail.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: Math.round(24 * Config.scale)
        }
        clip: true

        readonly property real cellWidth: Math.floor((width - 3 * page.pad) / 4)

        Text {
            id: title
            anchors {
                left: parent.left
                top: parent.top
            }
            text: page.device === "cpu" ? "CPU" : page.device === "memory" ? "Memory" : "GPU " + page.gpus.indexOf(page.gpu)
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize * 1.7
            font.weight: Font.DemiBold
        }

        Value {
            anchors {
                right: parent.right
                baseline: title.baseline
                left: title.right
                leftMargin: page.pad
            }
            horizontalAlignment: Text.AlignRight
            text: !page.sample ? "" : page.device === "cpu" ? page.sample.cpu.name : page.device === "memory" ? Units.bytes(page.sample.memory.total) : page.gpu ? page.gpu.name : ""
            color: Theme.colors.fgVariant
        }

        // Over the graph: what it is, and the scale's top.
        Item {
            id: caption
            anchors {
                left: parent.left
                right: parent.right
                top: title.bottom
                topMargin: Math.round(14 * Config.scale)
            }
            height: captionLabel.implicitHeight

            Label {
                id: captionLabel
                text: page.device === "cpu" ? (page.perCore ? "% Utilization per logical processor" : "% Utilization over 60 seconds") : page.device === "memory" ? "Memory usage" : "% Utilization"
            }

            Label {
                anchors.right: parent.right
                text: page.device === "memory" && page.sample ? Units.bytes(page.sample.memory.total) : "100%"
            }
        }

        // The graph: the frame Task Manager draws, a click on the CPU's flips it per core.
        Rectangle {
            id: frame
            anchors {
                left: parent.left
                right: parent.right
                top: caption.bottom
                topMargin: 4
            }
            height: Math.round(page.device === "cpu" ? 220 : 200) * Config.scale
            radius: 4
            color: Theme.colors.surfaceContainerLow
            border.width: 1
            border.color: Qt.alpha(Theme.colors.primary, 0.5)
            clip: true

            Graph {
                anchors.fill: parent
                anchors.margins: 1
                visible: !(page.device === "cpu" && page.perCore)
                values: page.device === "cpu" ? page.history.cpu : page.device === "memory" ? page.history.memory : page.gpu ? (page.history.gpus[page.gpu.id] || []) : []
            }

            Grid {
                anchors.fill: parent
                anchors.margins: Math.round(4 * Config.scale)
                visible: page.device === "cpu" && page.perCore
                readonly property int count: page.history.cores.length
                columns: Math.max(1, Math.ceil(Math.sqrt(count * 1.6)))
                rows: Math.max(1, Math.ceil(count / columns))
                spacing: Math.round(4 * Config.scale)

                Repeater {
                    model: page.perCore ? page.history.cores : []

                    Rectangle {
                        required property var modelData
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        height: (parent.height - (parent.rows - 1) * parent.spacing) / parent.rows
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(Theme.colors.primary, 0.3)

                        Graph {
                            anchors.fill: parent
                            anchors.margins: 1
                            values: parent.modelData
                            grid: false
                            lineWidth: 1
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: page.device === "cpu"
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: page.perCore = !page.perCore
            }
        }

        // A second graph for a GPU: its memory.
        Item {
            id: second
            anchors {
                left: parent.left
                right: parent.right
                top: frame.bottom
                topMargin: Math.round(10 * Config.scale)
            }
            height: visible ? memCaption.height + memFrame.height + 4 : 0
            visible: page.gpu !== null && !!page.gpu.memTotal

            Label {
                id: memCaption
                text: "Dedicated GPU memory usage"
            }

            Label {
                anchors.right: parent.right
                text: page.gpu && page.gpu.memTotal ? Units.bytes(page.gpu.memTotal) : ""
            }

            Rectangle {
                id: memFrame
                anchors {
                    left: parent.left
                    right: parent.right
                    top: memCaption.bottom
                    topMargin: 4
                }
                height: Math.round(90 * Config.scale)
                radius: 4
                color: Theme.colors.surfaceContainerLow
                border.width: 1
                border.color: Qt.alpha(Theme.colors.primary, 0.5)
                clip: true

                Graph {
                    anchors.fill: parent
                    anchors.margins: 1
                    values: page.gpu ? (page.history.gpuMemory[page.gpu.id] || []) : []
                }
            }
        }

        // Memory composition: in use, cached, free, in one bar.
        Item {
            id: composition
            anchors {
                left: parent.left
                right: parent.right
                top: frame.bottom
                topMargin: Math.round(10 * Config.scale)
            }
            height: visible ? Math.round(44 * Config.scale) : 0
            visible: page.device === "memory" && page.sample !== null

            readonly property var m: page.sample ? page.sample.memory : null
            readonly property real used: m && m.total ? m.used / m.total : 0
            readonly property real cached: m && m.total ? Math.max(0, m.available - m.free) / m.total : 0

            Label { text: "Memory composition" }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: Math.round(22 * Config.scale)
                radius: 4
                color: Theme.colors.surfaceContainerLow
                border.width: 1
                border.color: Qt.alpha(Theme.colors.primary, 0.5)
                clip: true

                Rectangle {
                    x: 1
                    y: 1
                    height: parent.height - 2
                    width: Math.round((parent.width - 2) * composition.used)
                    color: Qt.alpha(Theme.colors.primary, 0.7)
                }

                Rectangle {
                    x: 1 + Math.round((parent.width - 2) * composition.used)
                    y: 1
                    height: parent.height - 2
                    width: Math.round((parent.width - 2) * composition.cached)
                    color: Qt.alpha(Theme.colors.primary, 0.25)
                }
            }
        }

        // The numbers.
        Grid {
            id: stats
            anchors {
                left: parent.left
                right: parent.right
                top: page.device === "memory" ? composition.bottom : second.bottom
                topMargin: Math.round(18 * Config.scale)
            }
            columns: 4
            columnSpacing: page.pad
            rowSpacing: Math.round(12 * Config.scale)
            readonly property real cellWidth: detail.cellWidth

            Repeater {
                model: {
                    if (!page.sample)
                        return [];
                    const s = page.sample;
                    if (page.device === "cpu") {
                        const c = s.cpu;
                        return [
                            { label: "Utilization", value: Units.percent(c.usage) },
                            { label: "Speed", value: Units.ghz(c.freqMhz) },
                            { label: "Kernel", value: Units.percent(c.kernel) },
                            { label: "Processes", value: Units.count(c.processes) },
                            { label: "Threads", value: Units.count(c.threads) },
                            { label: "Handles", value: Units.count(c.handles) },
                            { label: "Up time", value: Units.duration(c.uptime) },
                            { label: "Base speed", value: c.baseKhz ? Units.ghz(c.baseKhz / 1000) : "" },
                            { label: "Temperature", value: c.temp != null ? Math.round(c.temp) + " °C" : "" },
                            { label: "Logical processors", value: String(c.cores.length) },
                            { label: "Sockets", value: c.sockets ? String(c.sockets) : "" },
                            { label: "Power", value: c.power != null ? c.power.toFixed(1) + " W" : "" },
                            { label: "L1 cache", value: c.l1 ? Units.bytes(c.l1) : "" },
                            { label: "L2 cache", value: c.l2 ? Units.bytes(c.l2) : "" },
                            { label: "L3 cache", value: c.l3 ? Units.bytes(c.l3) : "" },
                            { label: "Governor", value: c.governor || "" },
                            { label: "Virtualization", value: c.virtualization || "" }
                        ];
                    }
                    if (page.device === "memory") {
                        const m = s.memory;
                        return [
                            { label: "In use", value: Units.bytes(m.used) },
                            { label: "Available", value: Units.bytes(m.available) },
                            { label: "Cached", value: Units.bytes(m.cached) },
                            { label: "Committed", value: Units.bytes(m.committed) + " / " + Units.bytes(m.commitLimit) },
                            { label: "Swap", value: m.swapTotal ? Units.bytes(m.swapTotal - m.swapFree) + " / " + Units.bytes(m.swapTotal) : "None" },
                            { label: "Compressed", value: m.zswapped ? Units.bytes(m.zswapped) + " in " + Units.bytes(m.zswap) : "" },
                            { label: "Free", value: Units.bytes(m.free) },
                            { label: "Shared", value: Units.bytes(m.shmem) },
                            { label: "Dirty", value: Units.bytes(m.dirty) }
                        ];
                    }
                    const g = page.gpu;
                    if (!g)
                        return [];
                    return [
                        { label: "Utilization", value: Units.percent(g.usage || 0) },
                        { label: "Dedicated memory", value: g.memTotal ? Units.bytes(g.memUsed || 0) + " / " + Units.bytes(g.memTotal) : "" },
                        { label: "Shared memory", value: g.sharedTotal ? Units.bytes(g.sharedUsed || 0) + " / " + Units.bytes(g.sharedTotal) : "" },
                        { label: "Temperature", value: g.temp != null ? Math.round(g.temp) + " °C" : "" },
                        { label: "Power", value: g.power != null ? g.power.toFixed(0) + " W" + (g.maxPower ? " / " + g.maxPower.toFixed(0) + " W" : "") : "" },
                        { label: "Clock", value: g.clock ? g.clock + " MHz" + (g.maxClock ? " / " + g.maxClock + " MHz" : "") : "" },
                        { label: "Memory clock", value: g.memClock ? g.memClock + " MHz" + (g.maxMemClock ? " / " + g.maxMemClock + " MHz" : "") : "" },
                        { label: "Video encode", value: g.encode != null ? Units.percent(g.encode) : "" },
                        { label: "Video decode", value: g.decode != null ? Units.percent(g.decode) : "" },
                        { label: "PCI Express", value: g.pcieGen ? "Gen " + g.pcieGen + (g.pcieLanes ? " x" + g.pcieLanes : "") : "" },
                        { label: "Bus", value: g.id }
                    ];
                }

                Stat {
                    required property var modelData
                    label: modelData.label
                    value: modelData.value
                }
            }
        }
    }
}
