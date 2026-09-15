pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// The default output and input through PipeWire. Any change to the output's level or
// mute, from the keys, the card or another app, shows the OSD.
//
// The microphone on the rail: shown while an app has a capture stream open, its level
// from ikigai-miclevel for as long as that lasts, and its mute is Discord's own when
// Discord is running, through the Mute entry of Discord's tray menu, so the rail and
// Discord always agree; otherwise the input's mute in PipeWire.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : true
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    // Something is capturing: an app with an input stream open, our own meter aside.
    readonly property bool recording: Pipewire.nodes.values.some(n => n.type === PwNodeType.AudioInStream && n.name !== "ikigai-miclevel")
    // The input's level, 0 to 1, while something is recording.
    property real level: 0

    // Discord's Mute, from its tray menu: null when Discord is not up.
    readonly property var discordMute: discordMenu.children.values.find(e => e.text === "Mute") || null
    readonly property bool discordMuted: discordMute !== null && discordMute.checkState === Qt.Checked
    // What the rail's microphone shows: silent for whoever is listening.
    readonly property bool micOff: micMuted || discordMuted

    QsMenuOpener {
        id: discordMenu
        menu: {
            const item = Tray.items.find(i => (i.id || "").toLowerCase().startsWith("discord"));
            return item ? item.menu : null;
        }
    }

    Process {
        id: meter
        command: ["ikigai-miclevel"]
        running: root.recording
        stdout: SplitParser {
            onRead: line => root.level = parseFloat(line) || 0
        }
        onRunningChanged: if (!running) root.level = 0
    }
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio !== null)
    readonly property string icon: !ready || muted || volume === 0 ? "speaker-slash" : volume < 0.34 ? "speaker-none" : volume < 0.67 ? "speaker-low" : "speaker-high"

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    function nameOf(node) {
        return node.nickname || node.description || node.name;
    }

    function select(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setVolume(v) {
        if (ready)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function step(delta) {
        setVolume(volume + delta);
    }

    function toggleMute() {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    // Off anywhere means off: unmute everything; on means mute where it counts, Discord
    // when it is up, else the input.
    function toggleMicMute() {
        if (micOff) {
            if (micMuted && source && source.audio)
                source.audio.muted = false;
            if (discordMuted)
                discordMute.triggered();
        } else if (discordMute) {
            discordMute.triggered();
        } else if (source && source.audio) {
            source.audio.muted = true;
        }
    }

    onVolumeChanged: Osd.show("volume")
    onMutedChanged: Osd.show("volume")
    onMicMutedChanged: Osd.show("mic")
}
