import Quickshell
import Quickshell.Io
import QtQuick

// The launcher: a Drop on the focused screen with Vicinae as the card's content. Its
// window, chrome transparent and the card's size (config/vicinae/settings.json), opens as
// the card lands and sits over it on the overlay layer. Vicinae hides itself on Escape, on a launch or on focus loss and has
// no hook for it, so while it is up `vicinae state open` is polled and the card lifts
// when it says closed. `ikigai-shell launcher open|close|toggle`, Super's binding.
Scope {
    id: launcher

    property bool open: false
    // Vicinae's window is up inside the card.
    property bool vicinae: false
    // When to open Vicinae after the drop starts: its window maps in about 100 ms and
    // fades in over a tick, so this puts it on the card as the card settles.
    readonly property int reveal: 300

    function toggle() {
        open = !open;
    }

    onOpenChanged: {
        console.info("launcher", open ? "open" : "close");
        if (open) {
            revealTimer.restart();
        } else {
            revealTimer.stop();
            if (vicinae) {
                vicinae = false;
                vicinaeClose.running = true;
            }
        }
    }

    Timer {
        id: revealTimer
        interval: launcher.reveal
        onTriggered: vicinaeOpen.running = true
    }

    Process {
        id: vicinaeOpen
        command: ["vicinae", "open"]
        onExited: (code, status) => {
            if (!launcher.open)
                return;
            if (code === 0) {
                launcher.vicinae = true;
            } else {
                console.warn("launcher: vicinae open failed", code);
                launcher.open = false;
            }
        }
    }

    Process {
        id: vicinaeClose
        command: ["vicinae", "close"]
    }

    // Vicinae closed on its own: lift the card.
    Timer {
        interval: 100
        repeat: true
        running: launcher.vicinae
        onTriggered: if (!vicinaeState.running) vicinaeState.running = true
    }

    Process {
        id: vicinaeState
        command: ["vicinae", "state", "open"]
        onExited: (code, status) => {
            if (code !== 0 && launcher.vicinae) {
                console.info("launcher: vicinae closed");
                launcher.vicinae = false;
                launcher.open = false;
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function open(): void { launcher.open = true; }
        function close(): void { launcher.open = false; }
        function toggle(): void { launcher.toggle(); }
    }

    // The focused screen, which is where Vicinae puts its window. Keys during the drop
    // (Escape); Vicinae takes them once it is up.
    Drop {
        open: launcher.open
        // Vicinae's window size (launcher_window.size in config/vicinae/settings.json).
        cardWidth: 770
        cardHeight: 480
        keyboard: launcher.open && !launcher.vicinae
        namespace: "ikigai:launcher"
        onDismiss: launcher.open = false
    }
}
