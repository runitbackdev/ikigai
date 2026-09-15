pragma Singleton
import Quickshell
import QtQuick

// The two rail groups: pinned apps in order, with running unpinned apps appended to the top.
Singleton {
    id: root

    property var running: []
    signal taskViewToggled

    // Windows that are not apps: the launcher's is a toplevel too, and shows for as long
    // as it is open. Restore leaves these alone as well.
    readonly property var hidden: ["vicinae"]

    readonly property var top: layout([...Config.pinned.top, ...running.filter(a => !pinnedAnywhere(a))])
    readonly property var bottom: layout([...Config.pinned.bottom])

    Connections {
        target: Bridge
        function onWindowsChanged() {
            const live = [];
            for (const w of Bridge.windows)
                if (!live.includes(w.appId) && !root.hidden.includes(w.appId))
                    live.push(w.appId);
            root.running = [...root.running.filter(a => live.includes(a)), ...live.filter(a => !root.running.includes(a))];
        }
    }

    // A rail set to its own screen (`taskbar: "screen"` in shell.json): each task's windows
    // on that output only, and running unpinned apps only where they have one.
    function onScreen(tasks, screen) {
        if (Config.taskbar !== "screen" || !screen)
            return tasks;
        return tasks.map(t => Object.assign({}, t, { windows: t.windows.filter(w => w.outputs.includes(screen.name)) })).filter(t => t.pinned || t.windows.length > 0);
    }

    // Does this app have a rail button right now — pinned, or running and appended?
    function shows(appId) {
        return top.some(t => t.appId === appId) || bottom.some(t => t.appId === appId);
    }

    function pinnedAnywhere(appId) {
        return Config.pinned.top.includes(appId) || Config.pinned.bottom.includes(appId);
    }

    function layout(ids) {
        const windows = Bridge.windows;
        const apps = DesktopEntries.applications.values;
        return ids.map(appId => ({
            appId: appId,
            entry: Apps.entryFor(appId),
            pinned: pinnedAnywhere(appId),
            windows: windows.filter(w => w.appId === appId)
        }));
    }
}
