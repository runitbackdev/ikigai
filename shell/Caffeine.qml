pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Keep the screen on, from the rail: ikigai-caffeinate held as a child of the shell,
// until turned off or for a while. A caffeinate started from a terminal is its own and
// does not show here.
Singleton {
    id: root

    readonly property bool active: proc.running
    // Minutes asked for, 0 for until turned off; when it ends, as a time, for the card.
    property int minutes: 0
    property double until: 0
    readonly property var choices: [
        { minutes: 0, label: "Until turned off" },
        { minutes: 30, label: "30 minutes" },
        { minutes: 90, label: "90 minutes" },
        { minutes: 180, label: "3 hours" }
    ]

    function start(mins) {
        if (proc.running)
            proc.running = false;
        minutes = mins;
        until = mins > 0 ? Date.now() + mins * 60000 : 0;
        proc.command = mins > 0 ? ["ikigai-caffeinate", "-t", mins + "m"] : ["ikigai-caffeinate"];
        proc.running = true;
    }

    function stop() {
        proc.running = false;
    }

    function toggle() {
        if (active)
            stop();
        else
            start(0);
    }

    Process {
        id: proc
        onExited: (code, status) => {
            if (code !== 0 && code !== 143)
                console.warn("caffeine: ikigai-caffeinate exited", code);
        }
    }
}
