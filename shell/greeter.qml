//@ pragma IconTheme Cosmic
import Quickshell
import Quickshell.Wayland
import QtQuick

// greetd's greeter, run by ikigai-greeter under cosmic-comp: the theme's wallpaper on
// every screen and the login card on the last user's primary (their shell leaves its
// port or name in /var/lib/ikigai/greeter; the port survives the compositor naming the
// screen differently this boot, Ports.qml), else the first screen the compositor lists.
ShellRoot {
    id: root

    readonly property var primary: {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === Users.lastMonitor || Ports.id(screens[i].name) === Users.lastMonitor)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: modelData === root.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "ikigai:greeter"
            color: Theme.colors.surface

            // Decoded at the screen's size, not the file's, and faded in once ready.
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
                active: modelData === root.primary
                focus: true
                sourceComponent: Login {}
            }
        }
    }
}
