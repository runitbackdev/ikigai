pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as Bluez
import QtQuick

// Bluetooth over bluez: the default adapter, its switch, and the devices it knows or can
// see. Device state lives on bluez's objects, so the rows bind to them directly; only the
// count of connected ones is kept here, for the rail glyph.
//
// Pairing prompts come through ikigai-btagent, bluez's agent run as a child for as long
// as there is an adapter: each request lands in `request` for BluetoothAuth to show,
// `answer` sends the reply back.
Singleton {
    id: root

    readonly property Bluez.BluetoothAdapter adapter: Bluez.Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool enabled: present && adapter.enabled
    readonly property bool discovering: present && adapter.discovering
    readonly property var devices: present ? adapter.devices.values : []
    property int connectedCount: 0
    property string error: ""
    // The pairing prompt up, if any: { id, kind, device, name, passkey, entered, uuid }.
    // `display` prompts have no answer; they go when the device is done or gives up.
    property var request: null

    readonly property string icon: !enabled ? "bluetooth-slash" : connectedCount > 0 ? "bluetooth-connected" : "bluetooth"
    readonly property string status: !present ? "No Bluetooth hardware" : !enabled ? "Bluetooth is off" : connectedCount === 0 ? (discovering ? "Searching" : "Bluetooth") : connectedNames()

    // Paired devices first, connected among them, then whatever is in range with a name.
    // Nameless advertisers (bluez shows their address) are noise in a card this size.
    readonly property var listed: devices.filter(d => d.paired || d.bonded || !/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/i.test(d.name)).sort((a, b) => (b.connected - a.connected) || ((b.paired || b.bonded) - (a.paired || a.bonded)) || a.name.localeCompare(b.name))

    function connectedNames() {
        return devices.filter(d => d.connected).map(d => d.name).join(", ");
    }

    function setEnabled(on) {
        if (present)
            adapter.enabled = on;
    }

    function setDiscovering(on) {
        if (enabled && adapter.discovering !== on)
            adapter.discovering = on;
    }

    // Pairing a fresh device, or connecting a paired one. A paired device is marked trusted
    // so bluez lets it reconnect on its own (headphones switched on, a mouse woken).
    function connect(device) {
        error = "";
        if (device.paired || device.bonded) {
            device.trusted = true;
            device.connect();
        } else {
            device.pair();
        }
    }

    function disconnect(device) {
        device.disconnect();
    }

    function forget(device) {
        device.forget();
    }

    // bluez icon names (the device's class) to Phosphor.
    function glyphFor(device) {
        switch (device.icon) {
        case "audio-headset":
        case "audio-headphones":
            return "headphones";
        case "audio-card":
        case "audio-speakers":
            return "speaker-high";
        case "input-mouse":
            return "mouse-simple";
        case "input-keyboard":
            return "keyboard";
        case "input-gaming":
            return "game-controller";
        case "phone":
            return "device-mobile";
        case "computer":
            return "desktop";
        case "camera-photo":
        case "camera-video":
            return "camera";
        case "printer":
            return "printer";
        default:
            return "bluetooth";
        }
    }

    function recount() {
        connectedCount = devices.filter(d => d.connected).length;
    }

    function answer(ok, value) {
        if (!request)
            return;
        if (request.id > 0)
            agent.write(JSON.stringify({ id: request.id, ok: !!ok, value: value === undefined ? "" : String(value) }) + "\n");
        request = null;
    }

    Process {
        id: agent
        command: ["ikigai-btagent"]
        running: root.present
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                switch (msg.kind) {
                case "ready":
                    console.info("bluetooth: agent registered as", msg.name);
                    break;
                case "gone":
                    break;
                case "error":
                    console.warn("bluetooth: agent", msg.message);
                    break;
                case "cancel":
                    if (root.request && root.request.id === msg.id)
                        root.request = null;
                    break;
                default:
                    root.request = msg;
                }
            }
        }
        onExited: (code, status) => {
            root.request = null;
            if (code !== 0 && code !== 143)
                console.warn("bluetooth: ikigai-btagent exited", code);
        }
    }

    onDevicesChanged: recount()

    // One watcher per device: its connected flag and, once paired, the connect that follows.
    Instantiator {
        model: root.present ? root.adapter.devices : null

        delegate: QtObject {
            required property Bluez.BluetoothDevice modelData
            readonly property bool on: modelData.connected
            readonly property bool paired: modelData.paired || modelData.bonded
            readonly property bool pairing: modelData.pairing

            onOnChanged: root.recount()
            // Pairing over, either way: a display prompt has nothing left to show.
            onPairingChanged: {
                if (!pairing && root.request && root.request.kind === "display")
                    root.request = null;
            }
            onPairedChanged: {
                if (paired && !modelData.connected) {
                    modelData.trusted = true;
                    modelData.connect();
                }
            }
            Component.onDestruction: Qt.callLater(root.recount)
        }
    }
}
