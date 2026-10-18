import Quickshell
import Quickshell.Services.Polkit
import QtQuick

// The session's polkit agent, on the lock screen's card. Stock COSMIC had one inside
// cosmic-osd; without an agent a privilege prompt (Settings' Users page, a timezone
// change) fails with no dialog at all. polkit picks the identity to authenticate as,
// so the card names that account, which is not always the one logged in. Where polkit
// offers several admins its own pick stands; a chooser can come later.
Scope {
    id: scope

    readonly property var flow: agent.flow
    readonly property bool asking: flow !== null && !flow.isCompleted
    property var card: null

    readonly property var user: {
        const name = flow && flow.selectedIdentity ? flow.selectedIdentity.displayName : "";
        return Accounts.users.find(u => u.name === name) || { name: name, fullName: name, avatar: "" };
    }

    PolkitAgent {
        id: agent
    }

    Connections {
        target: scope.flow

        // polkit asks again after a wrong password, so the card recovers rather than closes.
        function onAuthenticationFailed() {
            if (scope.card)
                scope.card.reject(scope.flow.supplementaryMessage || "Authentication failed");
        }
    }

    // The window outlives the flow by its fade, with what the card said held so it does
    // not empty on the way out.
    property bool closing: false
    property var shownUser: null
    property string shownMessage: ""

    onAskingChanged: {
        closing = !asking;
        if (closing) {
            fade.restart();
        } else {
            fade.stop();
            // A new flow inside the last one's fade reuses its card, still busy.
            if (card) {
                card.busy = false;
                card.clear();
            }
        }
    }

    Timer {
        id: fade
        interval: Motion.defaultEffects
        onTriggered: scope.closing = false
    }

    Binding {
        target: scope
        property: "shownUser"
        value: scope.user
        when: scope.asking
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: scope
        property: "shownMessage"
        value: scope.flow ? scope.flow.message : ""
        when: scope.asking
        restoreMode: Binding.RestoreNone
    }

    LazyLoader {
        active: scope.asking || scope.closing

        DialogWindow {
            layerName: "polkit"
            closing: scope.closing
            onDismissed: scope.flow.cancelAuthenticationRequest()

            AuthCard {
                anchors.centerIn: parent
                user: scope.shownUser
                subtitle: scope.shownMessage
                shown: !scope.closing
                Component.onCompleted: scope.card = this
                onSubmit: password => scope.flow.submit(password)
            }
        }
    }
}
