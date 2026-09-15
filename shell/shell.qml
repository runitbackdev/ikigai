//@ pragma IconTheme Cosmic
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Switcher {}
    Shot {}
    Lock {}
    Polkit {}
    Welcome {}
    Launcher {}
    Monitor {}
    Restore {}
    WifiAuth {}
    BluetoothAuth {}

    IpcHandler {
        target: "osd"

        function brightness(direction: string): void {
            Osd.brightness(direction);
        }
    }

    IpcHandler {
        target: "taskview"

        function toggle(): void {
            Tasks.taskViewToggled();
        }
    }

    IpcHandler {
        target: "caffeine"

        function toggle(): void {
            Caffeine.toggle();
        }
    }

    IpcHandler {
        target: "sidebar"

        function toggle(): void {
            Notifs.toggleSidebar(Notifs.screen);
        }
    }
}
