pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/ikigai"

    property alias pinned: config.pinned
    property alias icons: config.icons
    property alias autohide: config.autohide
    property alias scale: config.scale
    property alias dnd: config.dnd
    property alias monitor: config.monitor
    property alias restore: config.restore
    property alias taskbar: config.taskbar

    function pin(appId) {
        config.pinned.top = [...config.pinned.top, appId];
        file.writeAdapter();
    }

    function setMonitor(name) {
        config.monitor = name;
        file.writeAdapter();
    }

    function setDnd(on) {
        config.dnd = on;
        file.writeAdapter();
    }

    function unpin(appId) {
        config.pinned.top = [...config.pinned.top].filter(a => a !== appId);
        config.pinned.bottom = [...config.pinned.bottom].filter(a => a !== appId);
        file.writeAdapter();
    }

    FileView {
        id: file
        path: root.configDir + "/shell.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: config

            property JsonObject pinned: JsonObject {
                property list<string> top: []
                property list<string> bottom: []
            }
            property var icons: ({})
            property bool autohide: true
            property real scale: 1.0
            property bool dnd: false
            property string monitor: ""
            property bool restore: true
            // "all": every rail shows every window; "screen": each rail its own output's.
            property string taskbar: "all"
        }
    }
}
