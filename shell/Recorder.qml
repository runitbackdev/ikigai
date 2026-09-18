pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// One screen recording at a time through gpu-screen-recorder: a rectangle on an output
// (its KMS path, no compositor protocol involved) or a whole output, with the system's
// audio, into ~/Videos/Recordings. Stopping saves the file and puts its path on the
// clipboard with a toast saying so (`ikigai-shot saved`). The shell only resolves the
// directory and execs the recorder, so the stop signal reaches the recorder itself. The encoder is the GPU's when ffmpeg can drive it
// and x264 on the CPU when not (the NVIDIA 580xx pin's NVENC API is older than Arch's
// ffmpeg wants); a recorder that exits without a file becomes a notification.
Singleton {
    id: recorder

    readonly property bool recording: process.running
    property date since
    property int seconds: 0
    property string file: ""
    property string lastError: ""
    readonly property string elapsed: (seconds < 600 ? "" : Math.floor(seconds / 3600) + ":") + pad(Math.floor(seconds / 60) % 60) + ":" + pad(seconds % 60)

    function pad(n) { return (n < 10 ? "0" : "") + n; }

    function fileName() {
        const d = new Date();
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "_" + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds()) + ".mp4";
    }

    // `rect` is in the screen's logical coordinates; null records the whole output.
    function start(screen, rect) {
        if (process.running)
            return;
        const dpr = screen.devicePixelRatio;
        const source = rect
            ? ["-w", "region", "-region", Math.round(rect.width * dpr) + "x" + Math.round(rect.height * dpr) + "+" + Math.round((screen.x + rect.x) * dpr) + "+" + Math.round((screen.y + rect.y) * dpr)]
            : ["-w", screen.name];
        console.info("record start", source.join(" "));
        file = "";
        lastError = "";
        process.command = ["sh", "-c",
            'd="$(xdg-user-dir VIDEOS)/Recordings" && mkdir -p "$d" && echo "$d/$0" && exec gpu-screen-recorder "$@" -o "$d/$0"',
            fileName(), ...source, "-f", "60", "-a", "default_output", "-c", "mp4", "-cursor", "yes", "-fallback-cpu-encoding", "yes"];
        since = new Date();
        seconds = 0;
        process.running = true;
    }

    function stop() {
        if (process.running)
            process.signal(2);
    }

    Process {
        id: process
        stdout: SplitParser {
            onRead: line => { if (!recorder.file) recorder.file = line; }
        }
        stderr: SplitParser {
            onRead: line => console.info("record:", line)
        }
        onExited: (code, status) => {
            console.info("record stopped", code, recorder.file);
            if (recorder.file)
                Quickshell.execDetached(["ikigai-shot", "saved", recorder.file]);
        }
    }

    Timer {
        running: recorder.recording
        interval: 1000
        repeat: true
        onTriggered: recorder.seconds = Math.floor((Date.now() - recorder.since.getTime()) / 1000)
    }
}
