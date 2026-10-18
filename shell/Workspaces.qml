import Quickshell
import QtQuick

// The workspaces of the screen this rail lives on. Every output carries its own 1, 2, ...,
// so listing all of them shows each number twice.
PopupCard {
    id: popup

    property var screen: null

    implicitWidth: 260
    implicitHeight: list.implicitHeight + 12

    Column {
        id: list
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        // Diffed by id: Bridge hands over fresh arrays on every event, and rebuilding the
        // rows would drop their hover and land the active tint without its fade. Only
        // while the card is up: every window event would refilter a hidden list.
        Repeater {
            model: ScriptModel {
                values: !popup.live ? [] : Bridge.workspaces.filter(w => !popup.screen || w.outputs.includes(popup.screen.name))
                objectProp: "id"
            }

            Item {
                id: row
                required property var modelData
                readonly property var windows: Bridge.windows.filter(w => w.workspaces.includes(modelData.id))

                width: list.width
                height: 40

                StateLayer {
                    active: row.modelData.active
                    hovered: rowHover.hovered
                    pressed: rowPress.pressed
                }

                Words {
                    id: name
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: row.modelData.name
                    color: row.modelData.active ? Theme.colors.primary : Theme.colors.fg
                    font.bold: row.modelData.active
                }

                HoverHandler {
                    id: rowHover
                }

                MouseArea {
                    id: rowPress
                    anchors.fill: parent
                    onClicked: {
                        popup.done();
                        Bridge.activateWorkspace(row.modelData.id);
                    }
                }

                Row {
                    anchors {
                        left: name.right
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    Repeater {
                        model: ScriptModel {
                            values: row.windows
                            objectProp: "id"
                        }

                        AppIcon {
                            id: icon
                            required property var modelData

                            source: Quickshell.iconPath(Apps.iconFor(modelData.appId), "application-x-executable")

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    popup.done();
                                    Bridge.activate(icon.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
