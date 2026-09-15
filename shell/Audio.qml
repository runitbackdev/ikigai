pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// The default output and input through PipeWire. Any change to the output's level or
// mute, from the keys, the card or another app, shows the OSD.
//
// The microphone on the rail: shown while an app has a capture stream open, its level
// from ikigai-miclevel for as long as that lasts; a click mutes the input in PipeWire.
// (Driving Discord's own mute through its tray menu was tried on 2026-09-15 and taken
// out: the entry is only there while in voice and the two never quite agreed.)
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

    // Every app playing sound, one entry per application name with all its streams,
    // for the volume card's per-app rows. The glyph is the rail's for the app when one
    // can be matched by name or binary, else a generic one.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream)
    readonly property var apps: {
        const groups = {};
        for (const n of streams) {
            const p = n.properties || {};
            const name = p["application.name"] || n.nickname || n.name || "?";
            if (!groups[name])
                groups[name] = { name: name, glyph: glyphForStream(n), nodes: [] };
            groups[name].nodes.push(n);
        }
        return Object.values(groups).sort((a, b) => a.name.localeCompare(b.name));
    }

    PwObjectTracker {
        objects: root.streams
    }

    function glyphForStream(node) {
        const p = node.properties || {};
        const hints = [p["application.name"], p["application.process.binary"], node.name].filter(h => h).map(h => h.toLowerCase());
        for (const appId of [...Config.pinned.top, ...Config.pinned.bottom, ...Tasks.running]) {
            const id = appId.toLowerCase();
            const last = Apps.short(appId).toLowerCase();
            if (hints.some(h => h === id || h === last || id.includes(h) || h.includes(last)))
                return Apps.glyphFor(appId);
        }
        if (hints.some(h => h.includes("wine") || h.endsWith(".exe")))
            return "game-controller";
        return "waveform";
    }

    function appVolume(app) {
        const n = app.nodes.find(n => n.audio);
        return n ? n.audio.volume : 0;
    }

    function appMuted(app) {
        return app.nodes.every(n => n.audio && n.audio.muted);
    }

    function setAppVolume(app, v) {
        for (const n of app.nodes)
            if (n.audio)
                n.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleAppMute(app) {
        const muted = appMuted(app);
        for (const n of app.nodes)
            if (n.audio)
                n.audio.muted = !muted;
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

    function toggleMicMute() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    onVolumeChanged: Osd.show("volume")
    onMutedChanged: Osd.show("volume")
    onMicMutedChanged: Osd.show("mic")
}
