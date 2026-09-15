import Quickshell
import Quickshell.Io
import QtQuick

// Reopen what was open at the last logout, each app on the output and workspace it had,
// the way macOS reopens windows and Windows restarts apps after sign-in. What comes back
// is the app, not its contents: each one reopens with whatever it remembers itself.
//
// Saving: a moment after every window change, while the bridge is up, the app windows go
// to ~/.local/state/ikigai/session.json as (app, output, workspace, maximized). The
// compositor going away drops the bridge and cancels the pending write, so a logout's
// mass close never empties the file.
//
// Restoring, once per login: ikigai-session clears the marker in XDG_RUNTIME_DIR at
// start, the shell writes it as restore begins, so a shell restart mid-session leaves the
// windows alone. Each app is launched once; its new windows claim the saved slots in
// order and are walked to their workspace (moving a window onto the last workspace makes
// cosmic-comp grow the next one). An app that settles with fewer windows than saved is
// launched again for the rest, once: Ghostty opens a window per launch, Zen and Discord
// reuse the running instance. An output that is not plugged in leaves its windows where
// they land. Off with "restore": false in shell.json.
//
// Ghostty's tabs come back too, each in the directory it was in, the way Windows Terminal
// does it: `ikigai-tabs` lists them (every half minute and after each window change) and
// they are saved with the windows. At restore they go into a queue in XDG_RUNTIME_DIR
// before Ghostty launches; every new Ghostty shell takes the first line and starts there.
// Once the first window is up, `ikigai-tabs open` asks it for the tabs the windows' own
// first shells will not take. Which tab was in which window is not known, so the first
// window gets the extras.
Scope {
    id: root

    readonly property string sessionPath: Theme.stateDir + "/session.json"
    readonly property string markerPath: Quickshell.env("XDG_RUNTIME_DIR") + "/ikigai-restored"
    readonly property string queuePath: Quickshell.env("XDG_RUNTIME_DIR") + "/ikigai-tabs"
    readonly property string ghostty: "com.mitchellh.ghostty"
    // The launcher's window is a toplevel too; reopening it at login would be absurd.
    readonly property var skip: ["vicinae"]

    property var saved: null
    property bool markerChecked: false
    // DesktopEntries fills in over the first moments; wait for it to go quiet.
    property bool entriesSettled: false
    property bool restoredThisLogin: false
    property bool restoring: false
    property bool saving: false
    // { appId, output, workspace, maximized, id, requested, maximizeAsked }
    property var slots: []
    property var ignored: ({})
    property var toppedUp: ({})
    property string lastWritten: ""
    // The Ghostty tab directories as last listed, and how many tabs restore still owes
    // beyond the windows' first shells.
    property var tabs: []
    property int pendingTabs: 0
    property bool tabsAsked: false

    function ready() {
        return saved !== null && markerChecked && entriesSettled && Bridge.connected && DesktopEntries.applications.values.length > 0;
    }

    function maybeStart() {
        if (restoring || saving || !ready())
            return;
        if (restoredThisLogin || !Config.restore) {
            saving = true;
            return;
        }
        start();
    }

    function start() {
        restoring = true;
        marker.setText(new Date().toISOString() + "\n");
        const present = {};
        for (const w of Bridge.windows)
            present[w.id] = true;
        ignored = present;
        toppedUp = {};
        slots = saved.windows.filter(s => Apps.entryFor(s.appId)).map(s => ({
            appId: s.appId, output: s.output, workspace: String(s.workspace), maximized: !!s.maximized,
            id: null, requested: null, maximizeAsked: false
        }));
        const tabs = Array.isArray(saved.tabs) ? saved.tabs.filter(t => typeof t === "string" && t) : [];
        const windows = slots.filter(s => s.appId === ghostty).length;
        pendingTabs = windows > 0 ? Math.max(0, tabs.length - windows) : 0;
        tabsAsked = false;
        if (windows > 0 && tabs.length > 0)
            queue.setText(tabs.join("\n") + "\n");
        console.info("restore:", slots.length, "windows from", sessionPath, tabs.length ? "and " + tabs.length + " tabs" : "");
        for (const appId of [...new Set(slots.map(s => s.appId))])
            Apps.launch(Apps.entryFor(appId));
        if (slots.length === 0)
            finish();
        else
            giveUp.start();
    }

    function settle() {
        if (!restoring)
            return;
        for (const w of Bridge.windows) {
            if (ignored[w.id] || slots.some(s => s.id === w.id))
                continue;
            const slot = slots.find(s => s.appId === w.appId && !s.id);
            if (slot)
                slot.id = w.id;
            else
                ignored[w.id] = true;
            if (slot && slot.appId === ghostty && !tabsAsked && pendingTabs > 0) {
                tabsAsked = true;
                console.info("restore: asking Ghostty for", pendingTabs, "more tabs");
                opener.command = ["ikigai-tabs", "open", String(pendingTabs)];
                opener.running = true;
            }
        }
        // Lowest workspace first: cosmic-comp collapses an empty workspace between two
        // used ones, so 3 only holds while 2 is occupied. A slot waits for the slots
        // below it on its output, including ones whose app has not shown up yet.
        const pending = slots.filter(s => s.id && !placed(s)).sort((a, b) => number(a) - number(b));
        for (const s of pending)
            if (!slots.some(o => o !== s && o.output === s.output && number(o) < number(s) && !placed(o)))
                step(s);
        if (slots.every(placed))
            finish();
    }

    function number(s) {
        const n = parseInt(s.workspace);
        return isNaN(n) ? 0 : n;
    }

    // Where the slot's window stands: gone, on an output that is not here, or on its
    // workspace. Maximizing is asked for once on arrival and not waited on.
    function placed(s) {
        if (!s.id)
            return false;
        const w = Bridge.windows.find(x => x.id === s.id);
        if (!w)
            return true;
        const onOutput = Bridge.workspaces.filter(ws => ws.outputs.includes(s.output));
        if (onOutput.length === 0)
            return true;
        if (!onOutput.some(ws => ws.name === s.workspace && w.workspaces.includes(ws.id)))
            return false;
        if (s.maximized && !s.maximizeAsked && !w.states.includes("maximized")) {
            s.maximizeAsked = true;
            Bridge.maximize(s.id);
        }
        return true;
    }

    // One move toward the slot's workspace: onto it if it exists, else onto the last one
    // on that output, which makes the next appear.
    function step(s) {
        const w = Bridge.windows.find(x => x.id === s.id);
        const onOutput = Bridge.workspaces.filter(ws => ws.outputs.includes(s.output));
        const target = onOutput.find(ws => ws.name === s.workspace) || last(onOutput);
        if (w.workspaces.includes(target.id) || s.requested === target.id)
            return;
        s.requested = target.id;
        Bridge.moveToWorkspace(s.id, target.id);
    }

    function last(workspaces) {
        return workspaces.reduce((a, b) => parseInt(b.name) > parseInt(a.name) ? b : a);
    }

    // The apps have had a quiet moment: any that showed up short of its saved windows
    // gets launched again for the rest.
    function topUp() {
        for (const appId of [...new Set(slots.map(s => s.appId))]) {
            if (toppedUp[appId])
                continue;
            const mine = slots.filter(s => s.appId === appId);
            const missing = mine.filter(s => !s.id).length;
            if (missing === mine.length || missing === 0)
                continue;
            toppedUp[appId] = true;
            console.info("restore: launching", appId, missing, "more");
            for (let i = 0; i < missing; i++)
                Apps.launch(Apps.entryFor(appId));
        }
    }

    function finish() {
        const unplaced = slots.filter(s => !placed(s)).length;
        console.info("restore: done" + (unplaced ? ", " + unplaced + " not placed" : ""));
        giveUp.stop();
        quiet.stop();
        restoring = false;
        slots = [];
        saving = true;
        if (!opener.running)
            drain.restart();
        debounce.restart();
    }

    function save() {
        if (!saving || !Bridge.connected)
            return;
        const windows = [];
        for (const w of Bridge.windows) {
            if (skip.includes(w.appId) || !Apps.entryFor(w.appId))
                continue;
            const space = Bridge.workspaces.find(ws => w.workspaces.includes(ws.id));
            const output = w.outputs[0] || (space && space.outputs[0]);
            if (!space || !output)
                continue;
            windows.push({ appId: w.appId, output: output, workspace: space.name, maximized: w.states.includes("maximized") });
        }
        const text = JSON.stringify({ windows: windows, tabs: tabs }, null, 2) + "\n";
        if (text === lastWritten)
            return;
        lastWritten = text;
        session.setText(text);
    }

    Connections {
        target: Bridge

        function onConnectedChanged() {
            if (!Bridge.connected)
                debounce.stop();
            root.maybeStart();
        }

        function onWindowsChanged() {
            if (root.restoring) {
                root.settle();
                quiet.restart();
            } else if (root.saving) {
                debounce.restart();
            }
        }

        function onWorkspacesChanged() {
            root.settle();
        }
    }

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            entries.restart();
        }
    }

    FileView {
        id: session
        path: root.sessionPath
        printErrors: false
        onLoaded: {
            let parsed = { windows: [] };
            try {
                parsed = JSON.parse(text());
            } catch (e) {
                console.warn("restore: unreadable", path, e);
            }
            root.saved = { windows: Array.isArray(parsed.windows) ? parsed.windows : [] };
            root.maybeStart();
        }
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("restore: cannot read", path, error);
            root.saved = { windows: [] };
            root.maybeStart();
        }
    }

    // The tab directories the new Ghostty shells take from, one per line.
    FileView {
        id: queue
        path: root.queuePath
        printErrors: false
    }

    Process {
        id: opener
        onExited: (code, status) => {
            if (code !== 0)
                console.warn("restore: ikigai-tabs open failed", code);
            if (!root.restoring)
                drain.restart();
        }
    }

    Process {
        id: probe
        command: ["ikigai-tabs"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.tabs = text.split("\n").filter(t => t);
                root.save();
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("restore: ikigai-tabs failed", code);
                root.save();
            }
        }
    }

    FileView {
        id: marker
        path: root.markerPath
        printErrors: false
        onLoaded: {
            root.restoredThisLogin = true;
            root.markerChecked = true;
            root.maybeStart();
        }
        onLoadFailed: error => {
            root.restoredThisLogin = error !== FileViewError.FileNotFound;
            root.markerChecked = true;
            root.maybeStart();
        }
    }

    Timer {
        id: entries
        interval: 1500
        running: true
        onTriggered: {
            root.entriesSettled = true;
            root.maybeStart();
        }
    }

    Timer {
        id: debounce
        interval: 2000
        onTriggered: {
            if (root.saving && Bridge.connected && !probe.running)
                probe.running = true;
        }
    }

    // Tabs open, close and change directory without a window changing.
    Timer {
        interval: 30000
        repeat: true
        running: root.saving && Bridge.connected
        onTriggered: debounce.restart()
    }

    // Whatever the shells did not take, a few seconds after restore is done, so a tab
    // opened later starts at home like any other.
    Timer {
        id: drain
        interval: 5000
        onTriggered: queue.setText("")
    }

    Timer {
        id: quiet
        interval: 3000
        onTriggered: root.topUp()
    }

    // An app that never shows a window (crashed, uninstalled, asked a question first)
    // should not hold the session's saving back forever.
    Timer {
        id: giveUp
        interval: 45000
        onTriggered: root.finish()
    }
}
