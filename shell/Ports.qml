pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Which port each connected screen is on: the GPU's PCI address and the connector's
// place among that GPU's connectors of its type, "0000:01:00.0/DP/2". The compositor
// knows a screen by the kernel's connector name (DP-2), and the kernel numbers connectors
// in the order the drivers register them: with two GPUs that order is a race at boot, and
// the same monitor is DP-2 one boot and DP-5 the next. The GPU's address and the
// connector's place on it do not move; that pair is what Windows keys its display layout
// on, and it is the only thing that tells two of the same model apart when both report
// serial 0, as this box's do.
Singleton {
    id: root

    // Connector name to port for every connected connector.
    property var byName: ({})

    function id(name) {
        return byName[name] || "";
    }

    function refresh() {
        list.running = false;
        list.running = true;
    }

    readonly property string script: [
        'for c in /sys/class/drm/card[0-9]*-*; do',
        '  [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue',
        '  n=${c##*/}; card=${n%%-*}; name=${n#*-}; type=${name%-*}; num=${name##*-}',
        '  pci=$(basename "$(readlink -f "/sys/class/drm/$card/device")")',
        '  i=1',
        '  for o in "/sys/class/drm/$card-$type"-*; do m=${o##*-}; [ "$m" -lt "$num" ] && i=$((i+1)); done',
        '  echo "$name $pci/$type/$i"',
        'done'
    ].join("\n")

    Process {
        id: list
        running: true
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const [name, port] = line.split(" ");
                    if (name && port)
                        map[name] = port;
                }
                root.byName = map;
            }
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.refresh();
        }
    }
}
