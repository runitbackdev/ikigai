pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// The notification server. Live ones become toasts; every one is copied into a session
// history for the sidebar. Do-not-disturb skips the toast for all but critical urgency.
Singleton {
    id: root

    property var toasts: []
    // Toasts on screen, which see a close from the app's side out themselves before they go.
    property var held: []
    property var history: []
    property int unread: 0
    // Unread count per app, so a rail button can badge its own. Keyed by desktop entry
    // id: the notification names itself by desktop-entry hint or app name, and the rail
    // by Wayland app_id, and Apps.entryFor is what reconciles the two.
    property var unreadBy: ({})
    // The screen showing the sidebar, null while it is closed: it opens on the rail that
    // asked for it, where toasts always land on `screen`.
    property ShellScreen sidebarScreen: null
    readonly property bool sidebarOpen: sidebarScreen !== null
    readonly property bool dnd: Config.dnd
    readonly property int defaultTimeout: 5000

    // Where toasts land, and where `ikigai-shell sidebar toggle` opens.
    readonly property ShellScreen screen: Screens.primary

    NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => root.receive(n)
    }

    function receive(n) {
        console.info("notification", n.appName, JSON.stringify(n.summary), "unread", unread + 1);
        n.tracked = true;
        n.closed.connect(() => {
            if (!root.held.includes(n))
                root.forget(n);
        });
        history = [snapshot(n), ...history].slice(0, 50);
        unread += 1;
        const app = key(n.desktopEntry || n.appName);
        unreadBy = Object.assign({}, unreadBy, { [app]: (unreadBy[app] || 0) + 1 });
        if (dnd && n.urgency !== NotificationUrgency.Critical)
            return;
        toasts = [...toasts, n];
    }

    // A no-op once it's gone: a row's release on destruction lands while the stack's
    // model is still applying the removal that destroyed it.
    function forget(n) {
        if (toasts.includes(n))
            toasts = toasts.filter(t => t !== n);
    }

    function hold(n) {
        held = [...held, n];
    }

    // Let go by a toast that never finished leaving (its screen went), so a notification
    // already closed doesn't sit in the list with nothing to show it.
    function release(n, closed) {
        const i = held.indexOf(n);
        if (i >= 0)
            held = held.filter((_, j) => j !== i);
        if (closed && !held.includes(n))
            forget(n);
    }

    function remove(entry) {
        history = history.filter(e => e !== entry);
    }

    function clear() {
        history = [];
    }

    onSidebarOpenChanged: if (sidebarOpen) {
        unread = 0;
        unreadBy = ({});
    }

    // Focusing an app is reading it.
    Connections {
        target: Bridge
        function onWindowsChanged() {
            for (const w of Bridge.windows)
                if (w.states.includes("activated"))
                    root.clearFor(w.appId);
        }
    }

    // One name for an app however it announced itself: a desktop entry id when we can
    // find one, the lowercased name when we cannot.
    function key(name) {
        if (!name)
            return "";
        const entry = Apps.entryFor(name);
        return (entry ? entry.id : name).toLowerCase();
    }

    function unreadFor(appId) {
        return unreadBy[key(appId)] || 0;
    }

    function clearFor(appId) {
        const app = key(appId);
        if (!unreadBy[app])
            return;
        const next = Object.assign({}, unreadBy);
        const seen = next[app];
        delete next[app];
        unreadBy = next;
        unread = Math.max(0, unread - seen);
    }

    // Asking again from the same screen closes it; from another, it moves there.
    function toggleSidebar(on) {
        sidebarScreen = !on || sidebarScreen === on ? null : on;
    }

    function snapshot(n) {
        return {
            id: n.id, appName: n.appName, icon: icon(n), summary: n.summary, body: n.body,
            image: n.image, urgency: n.urgency, time: new Date()
        };
    }

    // appIcon is a theme name, a path or a URL depending on the app; missing, the
    // desktop entry's icon.
    function icon(n) {
        if (n.appIcon.startsWith("/"))
            return "file://" + n.appIcon;
        if (n.appIcon.includes("://"))
            return n.appIcon;
        const name = n.appIcon || Apps.iconFor(n.desktopEntry || n.appName.toLowerCase());
        return Quickshell.iconPath(name, "dialog-information");
    }
}
