pragma Singleton
import Quickshell
import Quickshell.Io

// What the greeter offers besides the accounts: sessions from /usr/share/wayland-sessions,
// and the last choice kept in the greeter user's home.
Singleton {
    id: root

    property var sessions: []
    property alias lastUser: last.user
    property alias lastSession: last.session
    // The last user's primary screen as its port or name, written by their shell
    // (Screens.qml) to /var/lib/ikigai/greeter/<user>; empty means the first screen.
    readonly property string lastMonitor: monitorFile.path !== "" && monitorFile.loaded ? monitorFile.text().trim() : ""

    function remember(user, session) {
        last.user = user;
        last.session = session;
        lastFile.writeAdapter();
    }

    function parseSessions(out) {
        const byId = {};
        for (const line of out.split("\n")) {
            const m = line.match(/^.*\/([^/]+)\.desktop:(\w+)=(.*)$/);
            if (!m)
                continue;
            if (!byId[m[1]])
                byId[m[1]] = { id: m[1] };
            byId[m[1]][m[2]] = m[3];
        }
        return Object.values(byId)
            .filter(s => s.Exec)
            .map(s => ({ id: s.id, name: s.Name || s.id, exec: s.Exec, desktopNames: s.DesktopNames || "" }))
            .sort((a, b) => a.id === "ikigai" ? -1 : b.id === "ikigai" ? 1 : a.name.localeCompare(b.name));
    }

    Process {
        running: true
        command: ["sh", "-c", "grep -H -E '^(Name|Exec|DesktopNames)=' /usr/share/wayland-sessions/*.desktop"]
        stdout: StdioCollector {
            onStreamFinished: root.sessions = root.parseSessions(text)
        }
    }

    FileView {
        id: monitorFile
        path: root.lastUser !== "" ? "/var/lib/ikigai/greeter/" + root.lastUser : ""
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: lastFile
        path: Quickshell.env("HOME") + "/last.json"

        JsonAdapter {
            id: last
            property string user: ""
            property string session: "ikigai"
        }
    }
}
