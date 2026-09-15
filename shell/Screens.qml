pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// The primary screen: where the lock, polkit and welcome cards, the switcher and toasts
// go, and where the sidebar opens from the command line. Wayland has no primary output,
// so it is `monitor` in shell.json while that output is connected, else the first one the
// compositor announced (which is whichever cable it enumerated first, not the one you
// look at).
//
// Only real screens count. When every output drops off the bus at once (the monitors'
// sleep on NVIDIA) Qt invents a nameless placeholder, and a layer surface bound to it is
// left for the compositor to place: on the wrong output, where it then stays. With no
// real screen `primary` is null, and a window bound to it moves once one is back.
Singleton {
    id: screens

    readonly property var real: {
        const all = Quickshell.screens;
        const real = [];
        for (let i = 0; i < all.length; i++)
            if (all[i].name !== "")
                real.push(all[i]);
        return real;
    }

    readonly property ShellScreen primary: {
        for (const s of real)
            if (s.name === Config.monitor)
                return s;
        return real.length > 0 ? real[0] : null;
    }

    // Where keyboard focus is: the screen of the activated window, else the primary. The
    // launcher opens there. Not the switcher: Windows' Alt+Tab is on the primary display
    // whichever monitor the active window or the mouse is on, so ours is too.
    readonly property ShellScreen focused: {
        const w = Bridge.windows.find(w => w.states.includes("activated"));
        if (w)
            for (const s of real)
                if (w.outputs.includes(s.name))
                    return s;
        return primary;
    }

    // The greeter runs as its own user and cannot read shell.json, so the primary's name
    // goes where it can look: /var/lib/ikigai/greeter/<user>, a sticky world-writable dir
    // like /tmp (greeter/tmpfiles.conf). The compositor fork reads it as `primary_output`
    // in its own config, the output a seat falls back to and moves to when it appears,
    // so new windows land there after login and after the outputs wake. Both rewritten
    // whenever `monitor` changes.
    Process {
        id: tell
        command: ["sh", "-c", 'd=/var/lib/ikigai/greeter; [ -d "$d" ] && printf %s "$1" > "$d/$(id -un)"; c="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicComp/v1"; mkdir -p "$c" && printf \'"%s"\' "$1" > "$c/primary_output"', "-", Config.monitor]
        running: true
    }

    Connections {
        target: Config

        function onMonitorChanged() {
            tell.running = false;
            tell.running = true;
        }
    }

    // cosmic-comp opens new windows on its active output, and the active output follows
    // keyboard focus. Whatever it picked at login or when the outputs came back from
    // sleep is not the primary, so take focus there for an instant: the next window
    // lands on the primary. Also for the lock after it unlocks, whose surfaces got the
    // focus wherever the compositor put it.
    function nudge() {
        settle.restart();
    }

    onPrimaryChanged: {
        if (primary !== null)
            nudge();
    }

    // Outputs return in a burst of two to three seconds; nudge once it is over.
    Timer {
        id: settle
        interval: 500
        onTriggered: bait.active = true
    }

    Timer {
        interval: 100
        running: bait.active
        onTriggered: bait.active = false
    }

    LazyLoader {
        id: bait

        PanelWindow {
            screen: screens.primary
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:nudge"
            mask: Region {}
        }
    }
}
