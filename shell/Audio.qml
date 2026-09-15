pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire

// The default output and input through PipeWire. Any change to the output's level or
// mute, from the keys, the card or another app, shows the OSD.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : true
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    // Something is capturing: an app with an input stream open.
    readonly property bool recording: Pipewire.nodes.values.some(n => n.type === PwNodeType.AudioInStream)
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

    function toggleMicMute() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    onVolumeChanged: Osd.show("volume")
    onMutedChanged: Osd.show("volume")
    onMicMutedChanged: Osd.show("mic")
}
