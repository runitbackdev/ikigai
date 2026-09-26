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

            Image {
                anchors.fill: parent
                source: "file:///usr/local/share/ikigai/theme/wallpaper.jpg"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
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
