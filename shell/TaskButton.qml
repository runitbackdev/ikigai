import Quickshell
import QtQuick

Item {
    id: button

    required property var modelData
    readonly property var task: modelData
    readonly property bool running: task.windows.length > 0
    readonly property bool active: task.windows.some(w => w.states.includes("activated"))

    // Set by TaskGroup's add transition, like BarButton.grow.
    property real grow: 1

    signal menuRequested
    signal windowsRequested
    signal dismissRequested

    implicitWidth: Theme.barWidth - 8
    implicitHeight: Theme.barWidth - 8

    scale: press.pressed ? 0.88 : 1

    Behavior on scale {
        Anim {}
    }

    transform: Scale {
        origin.x: button.width / 2
        origin.y: button.height / 2
        xScale: button.grow
        yScale: button.grow
    }

    StateLayer {
        hovered: hover.hovered
        pressed: press.pressed
    }

    Glyph {
        anchors.centerIn: parent
        name: Apps.glyphFor(button.task.appId)
        size: Theme.iconSize
        fill: button.active
        color: button.active ? Theme.colors.primary : button.running ? Theme.colors.fg : Theme.colors.fgVariant
    }

    // What the app wants noticed, in the corner of its glyph: how many notifications
    // of its own are unread, and failing that a quiet dot while it sits in the tray.
    // The tray's own artwork never lands on the rail — the rail speaks in glyphs.
    Rectangle {
        readonly property int count: Notifs.unreadFor(button.task.appId)
        readonly property bool trayed: Tray.itemFor(button.task.appId) !== null
        readonly property bool shown: count > 0 || trayed
        readonly property int side: Math.round((count > 0 ? 13 : 6) * Config.scale)

        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 1
            bottomMargin: 1
        }
        visible: opacity > 0
        scale: shown ? 1 : 0
        opacity: shown ? 1 : 0
        width: count > 0 ? Math.max(side, label.implicitWidth + 6) : side
        height: side
        radius: height / 2
        color: count > 0 ? Theme.colors.primary : Theme.colors.fgVariant

        Behavior on scale {
            Anim { fast: true }
        }

        Behavior on opacity {
            Anim { effects: true }
        }

        Behavior on width {
            Anim { fast: true }
        }

        Behavior on height {
            Anim { fast: true }
        }

        Behavior on color {
            ColorAnim {}
        }

        Text {
            id: label
            anchors.centerIn: parent
            visible: parent.count > 0
            text: parent.count > 9 ? "9+" : parent.count
            color: Theme.colors.primaryFg
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(9 * Config.scale)
            font.bold: true
        }
    }

    // Running mark on the rail edge: short while running, long while focused.
    Rectangle {
        anchors {
            left: parent.left
            leftMargin: -3
            verticalCenter: parent.verticalCenter
        }
        width: 2
        height: button.active ? 16 : 6
        radius: 1
        color: Theme.colors.primary
        visible: button.running

        Behavior on height {
            Anim { fast: true }
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered && button.running)
                linger.restart();
            else
                linger.stop();
        }
    }

    // Resting on a running app opens its window list, like a taskbar thumbnail strip.
    Timer {
        id: linger
        interval: 300
        onTriggered: button.windowsRequested()
    }

    MouseArea {
        id: press
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onPressed: linger.stop()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                button.menuRequested();
                return;
            }
            button.dismissRequested();
            if (mouse.button === Qt.LeftButton)
                button.primary();
            else
                button.closeWindow();
        }
    }

    function primary() {
        if (!running) {
            launch();
            return;
        }
        const windows = task.windows;
        const current = windows.findIndex(w => w.states.includes("activated"));
        if (current < 0)
            Bridge.activate(windows[0].id);
        else if (windows.length === 1)
            Bridge.minimize(windows[0].id);
        else
            Bridge.activate(windows[(current + 1) % windows.length].id);
    }

    function closeWindow() {
        const target = task.windows.find(w => w.states.includes("activated")) || task.windows[0];
        if (target)
            Bridge.close(target.id);
    }

    function launch() {
        if (task.entry)
            Apps.launch(task.entry);
    }
}
