import Quickshell
import QtQuick

// The Processes page: apps first, each a row with its processes folded under a caret and
// its numbers summed, then every other process flat under Background processes. Columns
// sort on a click, the sort sticks while the card is up, and rows keep their place as
// numbers change. Typing searches by name or PID; Delete ends the selected task, Shift
// with it force-stops. The cell tint is the heat map: the more a cell uses, the deeper.
//
// An app is a window's app id, matched to processes by the binary its desktop entry runs
// (Magpie's own grouping knows nothing of Nix wrappers), plus every descendant of those
// processes that is not itself another app's root.
FocusScope {
    id: page

    property var sample: null
    property string search: ""
    property string sortKey: "cpu"
    property bool sortDesc: true
    property var expanded: ({})
    property string selected: ""
    property var rows: []

    signal terminate(var pids)
    signal kill(var pids)

    readonly property int rowHeight: Math.round(30 * Config.scale)
    readonly property var columns: [
        { key: "name", label: "Name", width: 0 },
        { key: "pid", label: "PID", width: Math.round(76 * Config.scale) },
        { key: "cpu", label: "CPU", width: Math.round(86 * Config.scale) },
        { key: "memory", label: "Memory", width: Math.round(108 * Config.scale) },
        { key: "gpu", label: "GPU", width: Math.round(78 * Config.scale) },
        { key: "gpuMemory", label: "GPU memory", width: Math.round(112 * Config.scale) }
    ]
    readonly property var selectedRow: rows.find(r => r.key === selected) || null

    onSampleChanged: rebuild()
    onSearchChanged: rebuild()
    onSortKeyChanged: rebuild()
    onSortDescChanged: rebuild()
    onExpandedChanged: rebuild()

    function baseName(path) {
        return path ? path.slice(path.lastIndexOf("/") + 1) : "";
    }

    // The names a process may go by, lowercased: its binary, the wrapper's dressing off,
    // and what it was started as.
    function keysOf(p) {
        const clean = s => s.replace(/^\./, "").replace(/-wrapped$/, "").toLowerCase();
        return [clean(p.exe), clean(p.argv0), p.name.toLowerCase()].filter(k => k);
    }

    function matches(keys, candidates) {
        for (const k of keys)
            for (const c of candidates)
                if (k === c || (c.length >= 3 && k.startsWith(c) && (k[c.length] === "-" || k[c.length] === ".")))
                    return true;
        return false;
    }

    function group(sample) {
        const byPid = new Map();
        const children = new Map();
        for (const p of sample.processes) {
            byPid.set(p.pid, p);
            if (!children.has(p.parent))
                children.set(p.parent, []);
            children.get(p.parent).push(p.pid);
        }

        // Every windowed app, then Magpie's own list for anything it saw that has no window.
        const apps = [];
        const seen = new Set();
        for (const w of Bridge.windows) {
            if (seen.has(w.appId))
                continue;
            seen.add(w.appId);
            const entry = Apps.entryFor(w.appId);
            const candidates = [w.appId.toLowerCase(), Apps.short(w.appId)];
            if (entry) {
                if (entry.command.length > 0)
                    candidates.push(baseName(entry.command[0]).toLowerCase());
                if (entry.startupClass)
                    candidates.push(entry.startupClass.toLowerCase());
            }
            apps.push({ id: "app:" + w.appId, name: entry ? entry.name : w.appId, glyph: Apps.glyphFor(w.appId), candidates: candidates, roots: [] });
        }
        for (const a of sample.apps)
            apps.push({ id: "magpie:" + a.id, name: a.name, glyph: Apps.glyphFor(a.id), candidates: [], roots: a.pids.filter(pid => byPid.has(pid)) });

        const rootOf = new Map();
        for (const app of apps) {
            if (app.candidates.length > 0)
                for (const p of sample.processes)
                    if (matches(keysOf(p), app.candidates))
                        app.roots.push(p.pid);
            for (const pid of app.roots)
                if (!rootOf.has(pid))
                    rootOf.set(pid, app.id);
        }

        const claimed = new Set();
        const groups = [];
        for (const app of apps) {
            const pids = [];
            const stack = app.roots.filter(pid => rootOf.get(pid) === app.id);
            while (stack.length > 0) {
                const pid = stack.pop();
                if (claimed.has(pid))
                    continue;
                claimed.add(pid);
                pids.push(pid);
                for (const c of children.get(pid) || [])
                    if (!rootOf.has(c) || rootOf.get(c) === app.id)
                        stack.push(c);
            }
            if (pids.length > 0)
                groups.push({ id: app.id, name: app.name, glyph: app.glyph, pids: pids });
        }
        const background = sample.processes.filter(p => !claimed.has(p.pid));
        return { byPid: byPid, groups: groups, background: background };
    }

    function processRow(p, depth) {
        return {
            key: "pid:" + p.pid, kind: "process", depth: depth, glyph: "", pid: p.pid, name: p.name,
            cpu: p.cpu, memory: p.memory, gpu: p.gpu, gpuMemory: p.gpuMemory, pids: [p.pid], count: 1,
            detail: p.cmd || p.name, state: p.state
        };
    }

    function compare(a, b) {
        const key = sortKey;
        let d;
        if (key === "name")
            d = a.name.localeCompare(b.name, undefined, { sensitivity: "base" });
        else
            d = a[key] - b[key];
        if (d === 0)
            d = a.pid - b.pid;
        return sortDesc ? -d : d;
    }

    function rebuild() {
        if (!sample) {
            rows = [];
            return;
        }
        const g = group(sample);
        const needle = search.trim().toLowerCase();
        const hit = r => !needle || r.name.toLowerCase().includes(needle) || String(r.pid).includes(needle);
        const out = [];

        const appRows = [];
        for (const grp of g.groups) {
            const members = grp.pids.map(pid => processRow(g.byPid.get(pid), 1)).filter(hit);
            const own = !needle || grp.name.toLowerCase().includes(needle);
            if (!own && members.length === 0)
                continue;
            const all = grp.pids.map(pid => g.byPid.get(pid));
            const sum = k => all.reduce((s, p) => s + p[k], 0);
            const row = {
                key: grp.id, kind: "group", depth: 0, glyph: grp.glyph, pid: all[0].pid, name: grp.name,
                cpu: sum("cpu"), memory: sum("memory"), gpu: sum("gpu"), gpuMemory: sum("gpuMemory"),
                pids: grp.pids, count: all.length, detail: all.length + (all.length === 1 ? " process" : " processes"),
                expanded: !!expanded[grp.id] || (needle && !own)
            };
            row.children = row.expanded ? (own ? grp.pids.map(pid => processRow(g.byPid.get(pid), 1)) : members).sort(compare) : [];
            appRows.push(row);
        }
        appRows.sort(compare);
        if (appRows.length > 0) {
            out.push({ key: "section:apps", kind: "section", name: "Apps", count: appRows.length, pid: 0 });
            for (const r of appRows) {
                out.push(r);
                for (const c of r.children)
                    out.push(c);
            }
        }

        const back = g.background.map(p => processRow(p, 0)).filter(hit).sort(compare);
        if (back.length > 0) {
            out.push({ key: "section:background", kind: "section", name: "Background processes", count: back.length, pid: 0 });
            for (const r of back)
                out.push(r);
        }
        rows = out;
        if (selected && !out.some(r => r.key === selected))
            selected = "";
    }

    function toggleGroup(key) {
        const e = Object.assign({}, expanded);
        if (e[key])
            delete e[key];
        else
            e[key] = true;
        expanded = e;
    }

    function move(by) {
        const selectable = rows.filter(r => r.kind !== "section");
        if (selectable.length === 0)
            return;
        let i = selectable.findIndex(r => r.key === selected);
        i = i < 0 ? (by > 0 ? 0 : selectable.length - 1) : Math.max(0, Math.min(selectable.length - 1, i + by));
        selected = selectable[i].key;
        list.positionViewAtIndex(rows.findIndex(r => r.key === selected), ListView.Contain);
    }

    function endTask(force) {
        const row = selectedRow;
        if (!row)
            return;
        if (force)
            page.kill(row.pids);
        else
            page.terminate(row.pids);
    }

    function sortBy(key) {
        if (sortKey === key)
            sortDesc = !sortDesc;
        else {
            sortKey = key;
            sortDesc = key !== "name";
        }
    }

    // Heat: how much of the machine a cell is, 0..1.
    function heat(row, key) {
        if (!sample || row.kind === "section")
            return 0;
        switch (key) {
        case "cpu": return row.cpu / 100;
        case "gpu": return row.gpu / 100;
        case "memory": return sample.memory.total ? row.memory / sample.memory.total : 0;
        case "gpuMemory": {
            const total = sample.gpus.reduce((s, g) => s + (g.memTotal || 0), 0);
            return total ? row.gpuMemory / total : 0;
        }
        }
        return 0;
    }

    function cell(row, key) {
        switch (key) {
        case "name": return row.name;
        case "pid": return row.kind === "group" ? "" : String(row.pid);
        case "cpu": return Units.percent(row.cpu);
        case "memory": return Units.bytes(row.memory);
        case "gpu": return Units.percent(row.gpu);
        case "gpuMemory": return Units.bytes(row.gpuMemory);
        }
        return "";
    }

    Keys.onPressed: event => {
        const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
        switch (event.key) {
        case Qt.Key_Down: move(1); break;
        case Qt.Key_Up: move(-1); break;
        case Qt.Key_PageDown: move(10); break;
        case Qt.Key_PageUp: move(-10); break;
        case Qt.Key_Home: move(-rows.length); break;
        case Qt.Key_End: move(rows.length); break;
        case Qt.Key_Delete: endTask(event.modifiers & Qt.ShiftModifier); break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (selectedRow && selectedRow.kind === "group")
                toggleGroup(selectedRow.key);
            break;
        case Qt.Key_Right:
            if (selectedRow && selectedRow.kind === "group" && !selectedRow.expanded)
                toggleGroup(selectedRow.key);
            break;
        case Qt.Key_Left:
            if (selectedRow && selectedRow.kind === "group" && selectedRow.expanded)
                toggleGroup(selectedRow.key);
            break;
        case Qt.Key_Backspace: search = search.slice(0, -1); break;
        case Qt.Key_Escape:
            if (!search)
                return;
            search = "";
            break;
        default:
            if (plain && event.text.length === 1 && event.text >= " ")
                search += event.text;
            else
                return;
        }
        event.accepted = true;
    }

    // Search on the left, the two actions on the right.
    Item {
        id: toolbar
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: Math.round(36 * Config.scale)

        Rectangle {
            id: searchBox
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: Math.round(300 * Config.scale)
            radius: height / 2
            color: Theme.colors.surfaceContainerHigh
            border.width: page.search ? 1 : 0
            border.color: Theme.colors.primary

            Glyph {
                id: searchGlyph
                anchors {
                    left: parent.left
                    leftMargin: Math.round(12 * Config.scale)
                    verticalCenter: parent.verticalCenter
                }
                name: "magnifying-glass"
                size: Math.round(16 * Config.scale)
                color: Theme.colors.fgVariant
            }

            Text {
                anchors {
                    left: searchGlyph.right
                    right: clearGlyph.left
                    leftMargin: Math.round(8 * Config.scale)
                    verticalCenter: parent.verticalCenter
                }
                text: page.search || "Type to search by name or PID"
                color: page.search ? Theme.colors.fg : Theme.colors.outline
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                elide: Text.ElideRight
            }

            Glyph {
                id: clearGlyph
                anchors {
                    right: parent.right
                    rightMargin: Math.round(10 * Config.scale)
                    verticalCenter: parent.verticalCenter
                }
                name: "x"
                size: Math.round(14 * Config.scale)
                color: Theme.colors.fgVariant
                visible: page.search !== ""

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: page.search = ""
                }
            }
        }

        Row {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: Math.round(8 * Config.scale)

            Pill {
                label: "Force stop"
                enabled: page.selectedRow !== null
                onClicked: page.endTask(true)
            }

            Pill {
                label: "End task"
                primary: true
                enabled: page.selectedRow !== null
                onClicked: page.endTask(false)
            }
        }
    }

    // The header: the columns' names, the sorted one with its arrow.
    Item {
        id: header
        anchors {
            left: parent.left
            right: parent.right
            top: toolbar.bottom
            topMargin: Math.round(12 * Config.scale)
        }
        height: page.rowHeight

        readonly property int fixed: page.columns.reduce((s, c) => s + c.width, 0)

        Row {
            anchors.fill: parent

            Repeater {
                model: page.columns

                Item {
                    id: head
                    required property var modelData
                    readonly property bool numeric: modelData.key !== "name"
                    readonly property bool sorted: page.sortKey === modelData.key

                    width: modelData.width > 0 ? modelData.width : header.width - header.fixed
                    height: header.height

                    StateLayer {
                        hovered: headHover.hovered
                    }

                    Row {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: head.numeric ? undefined : parent.left
                            right: head.numeric ? parent.right : undefined
                            leftMargin: Math.round(10 * Config.scale)
                            rightMargin: Math.round(10 * Config.scale)
                        }
                        spacing: 4
                        layoutDirection: head.numeric ? Qt.RightToLeft : Qt.LeftToRight

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: head.modelData.label
                            color: head.sorted ? Theme.colors.fg : Theme.colors.fgVariant
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize * 0.92
                            font.weight: Font.Medium
                        }

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: page.sortDesc ? "caret-down" : "caret-up"
                            size: Math.round(12 * Config.scale)
                            color: Theme.colors.primary
                            visible: head.sorted
                        }
                    }

                    HoverHandler {
                        id: headHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.sortBy(head.modelData.key)
                    }
                }
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: Theme.colors.outlineVariant
        }
    }

    ListView {
        id: list
        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: detailBar.visible ? detailBar.top : parent.bottom
            bottomMargin: detailBar.visible ? Math.round(8 * Config.scale) : 0
        }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Rows change value every tick; keeping delegates by key keeps the scroll still.
        model: ScriptModel {
            values: page.rows
            objectProp: "key"
        }

        delegate: Item {
            id: row
            required property var modelData
            readonly property bool section: modelData.kind === "section"
            readonly property bool isSelected: page.selected === modelData.key

            width: list.width
            height: section ? Math.round(34 * Config.scale) : page.rowHeight

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.colors.primary
                opacity: row.isSelected ? 0.18 : 0
                visible: !row.section
            }

            StateLayer {
                hovered: rowHover.hovered && !row.section && !row.isSelected
            }

            // Section: its name and count, low and small, with room above.
            Text {
                anchors {
                    left: parent.left
                    leftMargin: Math.round(10 * Config.scale)
                    bottom: parent.bottom
                    bottomMargin: Math.round(6 * Config.scale)
                }
                visible: row.section
                text: row.section ? row.modelData.name + " (" + row.modelData.count + ")" : ""
                color: Theme.colors.fgVariant
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize * 0.88
                font.weight: Font.DemiBold
            }

            Row {
                anchors.fill: parent
                visible: !row.section

                Repeater {
                    model: page.columns

                    Item {
                        id: cell
                        required property var modelData
                        readonly property bool name: modelData.key === "name"
                        readonly property real heat: page.heat(row.modelData, modelData.key)
                        readonly property string text: page.cell(row.modelData, modelData.key)

                        width: modelData.width > 0 ? modelData.width : header.width - header.fixed
                        height: row.height

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 4
                            color: Theme.colors.primary
                            opacity: cell.name ? 0 : Math.min(0.55, cell.heat * 0.9)
                            visible: opacity > 0.01
                        }

                        // Name: the indent, the group's caret, the app's glyph, the name.
                        Row {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: Math.round((6 + 18 * row.modelData.depth) * Config.scale)
                                rightMargin: Math.round(10 * Config.scale)
                            }
                            spacing: Math.round(6 * Config.scale)
                            visible: cell.name

                            Item {
                                width: Math.round(16 * Config.scale)
                                height: row.height

                                Glyph {
                                    anchors.centerIn: parent
                                    name: row.modelData.expanded ? "caret-down" : "caret-right"
                                    size: Math.round(12 * Config.scale)
                                    color: Theme.colors.fgVariant
                                    visible: row.modelData.kind === "group"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    enabled: row.modelData.kind === "group"
                                    onClicked: page.toggleGroup(row.modelData.key)
                                }
                            }

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.glyph || "cube"
                                size: Math.round(16 * Config.scale)
                                color: row.modelData.kind === "group" ? Theme.colors.fg : Theme.colors.outline
                                visible: row.modelData.depth === 0
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x
                                text: cell.text
                                color: Theme.colors.fg
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            anchors {
                                right: parent.right
                                rightMargin: Math.round(10 * Config.scale)
                                verticalCenter: parent.verticalCenter
                            }
                            visible: !cell.name
                            text: cell.text
                            color: cell.text === "0%" || cell.text === "0 MB" ? Theme.colors.outline : Theme.colors.fg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                        }
                    }
                }
            }

            HoverHandler {
                id: rowHover
            }

            MouseArea {
                anchors.fill: parent
                enabled: !row.section
                acceptedButtons: Qt.LeftButton
                onClicked: page.selected = row.modelData.key
                onDoubleClicked: if (row.modelData.kind === "group") page.toggleGroup(row.modelData.key)
            }
        }
    }

    // The selected row's command line, along the bottom.
    Rectangle {
        id: detailBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: detail.implicitHeight + Math.round(12 * Config.scale)
        radius: Theme.radius
        color: Theme.colors.surfaceContainerLow
        visible: page.selectedRow !== null && page.selectedRow.kind === "process"

        Text {
            id: detail
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: Math.round(10 * Config.scale)
            }
            text: page.selectedRow ? page.selectedRow.detail : ""
            color: Theme.colors.fgVariant
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize * 0.88
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }
    }
}
