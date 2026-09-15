pragma Singleton
import Quickshell
import Quickshell.Services.SystemTray

// Apps that put an icon in the tray on top of their own window: Discord and Steam both
// do, so each showed up twice on the rail, once as a glyph and once as its own artwork.
// The rail button owns the tray item instead — its menu folds into the task menu, and
// its icon rides the button as a badge, since that is where Discord draws its unread
// mark (it never sets NeedsAttention; it swaps the pixmap). Matching is by SNI id
// prefix: Steam's is "steam", Discord's carries a counter ("discord_status_icon_1").
Singleton {
    id: root

    readonly property var owners: ({
        "discord": "discord",
        "steam": "steam"
    })

    readonly property var items: SystemTray.items.values

    // Items that get no slot at all: the launcher's, since Super is its button.
    readonly property var hidden: ["vicinae"]

    // Items no rail button stands for: these keep their own slot above the clock.
    readonly property var loose: items.filter(item => root.ownerOf(item) === "" && !root.isHidden(item))

    function isHidden(item) {
        const key = ((item.id || "") + " " + (item.title || "")).toLowerCase();
        return hidden.some(name => key.includes(name));
    }

    // The appId whose rail button owns this item, or "" while nothing on the rail does.
    function ownerOf(item) {
        const id = (item.id || "").toLowerCase();
        for (const prefix in owners)
            if (id.startsWith(prefix) && Tasks.shows(owners[prefix]))
                return owners[prefix];
        return "";
    }

    function itemFor(appId) {
        return items.find(item => root.ownerOf(item) === appId) || null;
    }
}
