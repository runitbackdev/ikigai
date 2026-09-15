pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Whether ikigai-update has anything to do: asked a couple of minutes after the shell
// starts and every six hours after, by `ikigai-update --available`, which fetches and
// locks into scratch and touches nothing. The rail shows an arrow while it does; a
// click runs the update in a terminal, and the shell restart that follows asks again.
Singleton {
    id: root

    property bool available: false
    property string summary: ""

    function check() {
        if (!probe.running)
            probe.running = true;
    }

    function run() {
        Apps.spawn(["ghostty", "-e", "sh", "-c", "ikigai-update; printf '\\nEnter closes this window '; read -r _"]);
    }

    Process {
        id: probe
        command: ["ikigai-update", "--available"]
        stdout: StdioCollector {
            onStreamFinished: root.summary = text.trim()
        }
        onExited: (code, status) => {
            root.available = code === 0;
            if (code > 1)
                console.warn("updates: ikigai-update --available exited", code);
        }
    }

    Timer {
        interval: 2 * 60 * 1000
        running: true
        onTriggered: root.check()
    }

    Timer {
        interval: 6 * 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.check()
    }
}
