import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

// The lock screen: ext-session-lock surfaces on every screen with the wallpaper, and the
// auth card on the first checking the password through PAM. Locked and unlocked over
// IPC by the session launcher, which relays logind's Lock and Unlock signals and holds
// suspend back until `locked` reports the compositor has the lock.
Scope {
    id: scope

    IpcHandler {
        target: "session"

        function lock(): void {
            console.info("lock");
            scope.engage();
        }

        // Instant: logind unlocking from outside has nobody watching an exit.
        function unlock(): void {
            console.info("unlock");
            unlockTimer.stop();
            lock.locked = false;
        }

        // True once the compositor has covered every screen; the launcher waits for
        // this before letting logind suspend.
        function locked(): bool {
            return lock.secure;
        }
    }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER")

        // What PAM says on the way that is not a prompt: pam_faillock's "The account is
        // locked due to 3 failed logins. (9 minutes left to unlock)" comes as info lines
        // before the password prompt, and without them a locked account looks like a
        // password that stopped working.
        onPamMessage: {
            if (responseRequired)
                respond(scope.pending);
            else if (message !== "")
                scope.said = scope.said ? scope.said + " " + message : message;
        }

        onCompleted: result => {
            scope.pending = "";
            const said = scope.said;
            scope.said = "";
            if (result === PamResult.Success) {
                scope.unlocking = true;
                unlockTimer.restart();
            } else if (scope.card) {
                scope.card.reject(said || (result === PamResult.MaxTries ? "Too many attempts" : "Wrong password"));
            }
        }

        onError: error => {
            scope.pending = "";
            if (scope.card)
                scope.card.reject("PAM error: " + PamError.toString(error));
        }
    }

    property string pending: ""
    property string said: ""
    property var card: null
    property bool unlocking: false

    // The card fades out before the lock lets go. A timer rather than the animation's
    // end, so nothing about the animation can keep the screen locked.
    Timer {
        id: unlockTimer
        interval: Motion.standard
        onTriggered: {
            lock.locked = false;
            if (scope.card)
                scope.card.clear();
        }
    }

    // cosmic-comp moves keyboard focus to a lock surface only while fixing up a focus
    // that became invalid; with nothing focused (an empty desktop) it never does, and
    // the card would need a click. So take focus with an exclusive layer first, lock,
    // then drop the layer: its death is what makes the compositor look again.
    function engage() {
        // A lock asked for mid-exit keeps it: the card comes back, ready to type again.
        if (unlocking) {
            unlockTimer.stop();
            unlocking = false;
            if (card) {
                card.busy = false;
                card.clear();
            }
        }
        bait.active = true;
        engageTimer.restart();
    }

    Timer {
        id: engageTimer
        interval: 100
        onTriggered: {
            lock.locked = true;
            releaseTimer.restart();
        }
    }

    Timer {
        id: releaseTimer
        interval: 300
        onTriggered: bait.active = false
    }

    // logind's LockedHint outlives the shell. Set while the compositor holds the lock
    // and read at startup: once the lock client dies cosmic-comp keeps the screen blank,
    // so a restarted shell locks again instead of leaving the box unusable.
    readonly property string sessionPath: Quickshell.env("IKIGAI_SESSION_PATH")

    function setLockedHint(locked) {
        if (sessionPath)
            Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.login1", sessionPath, "org.freedesktop.login1.Session", "SetLockedHint", "b", locked ? "true" : "false"]);
    }

    Process {
        command: ["busctl", "--system", "get-property", "org.freedesktop.login1", scope.sessionPath, "org.freedesktop.login1.Session", "LockedHint"]
        running: scope.sessionPath !== ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "b true")
                    scope.engage();
            }
        }
    }

    LazyLoader {
        id: bait

        PanelWindow {
            screen: Screens.primary
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ikigai:lock-bait"
            mask: Region {}
        }
    }

    // The lock's keyboard focus went wherever the compositor put it when the surfaces
    // were made; after the outputs' sleep that is its own first output. With the primary
    // back, do the bait dance again so the card there is the one that types, and once
    // unlocked put the active output back on the primary for the next window.
    Connections {
        target: Screens

        function onPrimaryChanged() {
            if (lock.locked && Screens.primary !== null) {
                bait.active = true;
                releaseTimer.restart();
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: false
        onSecureChanged: scope.setLockedHint(secure)
        onLockedChanged: {
            if (!locked) {
                scope.unlocking = false;
                Screens.nudge();
            }
        }

        WlSessionLockSurface {
            id: surface
            color: Theme.colors.surface

            // Decoded at the screen's size, not the file's, and faded in over the
            // surface colour once ready rather than appearing mid-frame.
            Image {
                // Fades in on the first decode only; a later resize (output waking in another
                // mode, a scale change) re-decodes behind the old frame instead of blanking.
                property bool loaded: false

                anchors.fill: parent
                // Held back until the surface has its size, else the first decode is the
                // full file anyway, or runs at zero height, and the resize decodes it again.
                source: width > 0 && height > 0 ? "file:///usr/local/share/ikigai/theme/wallpaper.jpg" : ""
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                retainWhileLoading: true
                opacity: loaded ? 1 : 0
                onStatusChanged: if (status === Image.Ready) loaded = true

                Behavior on opacity {
                    Anim { effects: true; slow: true }
                }
            }

            Loader {
                anchors.centerIn: parent
                active: surface.screen === Screens.primary
                focus: true

                sourceComponent: AuthCard {
                    user: Accounts.current
                    shown: !scope.unlocking
                    Component.onCompleted: scope.card = this
                    onSubmit: password => {
                        scope.pending = password;
                        scope.said = "";
                        pam.start();
                    }
                }
            }
        }
    }
}
