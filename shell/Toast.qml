import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Effects

// One row of the toast sheet: icon, app, summary, body, image, actions. Clicking invokes
// the app's default action or dismisses; middle-click, the corner X, or a swipe to the
// right always dismisses. The timer pauses under the pointer and never runs for critical
// urgency. Leaves by fading, then tells the server, so the app hears expired or dismissed
// only once the row is gone.
//
// The image hint is a portrait or a picture: a chat app sends the sender's avatar, a
// screenshot tool sends the capture. A wide one is a banner under the text; anything
// squarer takes the icon slot, with the app icon as a badge in its corner.
Item {
    id: toast

    required property var modelData
    required property int index
    readonly property var n: modelData
    readonly property bool critical: n.urgency === NotificationUrgency.Critical
    readonly property int pad: Math.round(14 * Config.scale)
    readonly property int iconSize: Math.round(32 * Config.scale)
    readonly property int portraitSize: Math.round(48 * Config.scale)
    readonly property bool pictured: n.image !== "" && picture.status === Image.Ready
    readonly property bool banner: pictured && picture.implicitWidth >= picture.implicitHeight * 1.5
    readonly property bool portrait: pictured && !banner
    readonly property int slotSize: portrait ? portraitSize : iconSize
    readonly property var defaultAction: {
        for (let i = 0; i < n.actions.length; i++)
            if (n.actions[i].identifier === "default")
                return n.actions[i];
        return null;
    }
    readonly property int closeSize: Math.round(20 * Config.scale)
    property bool leaving: false

    width: Math.round(340 * Config.scale)
    height: column.implicitHeight + 2 * pad
    opacity: leaving ? 0 : 1

    Behavior on opacity {
        Anim { effects: true; fast: true }
    }

    function close(dismissed) {
        if (leaving)
            return;
        leaving = true;
        exit.dismissed = dismissed;
        exit.restart();
    }

    // The sheet keeps sliding the way it was thrown while the row fades.
    function swipeOut() {
        sheet.x = toast.width;
        close(true);
    }

    Timer {
        id: exit
        property bool dismissed: false
        interval: Motion.fastEffects
        onTriggered: exit.dismissed ? toast.n.dismiss() : toast.n.expire()
    }

    Timer {
        interval: toast.n.expireTimeout > 0 ? toast.n.expireTimeout : Notifs.defaultTimeout
        running: !hover.hovered && !toast.critical && toast.n.expireTimeout !== 0 && !toast.leaving
        onTriggered: toast.close(false)
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onTapped: (point, button) => {
            if (button === Qt.LeftButton && toast.defaultAction)
                toast.defaultAction.invoke();
            else
                toast.close(true);
        }
    }

    // Swipe: the sheet follows the pointer rightward, toward the screen edge it hangs
    // from. Let go past a third of the width, or flung, and it goes; else it springs back.
    DragHandler {
        id: drag
        target: sheet
        xAxis.minimum: 0
        yAxis.enabled: false
        onActiveChanged: {
            if (active || toast.leaving)
                return;
            if (sheet.x > toast.width / 3 || centroid.velocity.x > 800)
                toast.swipeOut();
            else
                sheet.x = 0;
        }
    }

    Item {
        id: sheet
        width: parent.width
        height: parent.height

        Behavior on x {
            enabled: !drag.active
            Anim { fast: true }
        }

        StateLayer {
            radius: 0
            hovered: hover.hovered
        }

        Rectangle {
            width: parent.width - 2 * toast.pad
            height: 1
            x: toast.pad
            color: Theme.colors.outlineVariant
            visible: toast.index > 0
        }

        // Dismiss, in the corner, there while the pointer is over the row.
        Item {
            x: parent.width - toast.pad - toast.closeSize + 4
            y: toast.pad - 4
            width: toast.closeSize
            height: toast.closeSize
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity {
                Anim { effects: true; fast: true }
            }

            StateLayer {
                radius: width / 2
                hovered: closeHover.hovered
                pressed: closeTap.pressed
            }

            Glyph {
                anchors.centerIn: parent
                name: "x"
                size: Math.round(14 * Config.scale)
                color: Theme.colors.fgVariant
            }

            HoverHandler {
                id: closeHover
            }

            TapHandler {
                id: closeTap
                onTapped: toast.close(true)
            }
        }

        Column {
            id: column
            x: toast.pad
            y: toast.pad
            width: parent.width - 2 * toast.pad
            spacing: Math.round(8 * Config.scale)

            Row {
                width: parent.width
                spacing: Math.round(10 * Config.scale)

                Item {
                    width: toast.slotSize
                    height: toast.slotSize

                    AppIcon {
                        source: Notifs.icon(toast.n)
                        size: toast.iconSize
                        visible: !toast.portrait
                    }

                    Rectangle {
                        id: mask
                        anchors.fill: parent
                        radius: Theme.radius
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: picture
                        maskEnabled: true
                        maskSource: mask
                        visible: toast.portrait
                    }

                    // Whose avatar this is: the app, in the corner.
                    AppIcon {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -2
                        source: Notifs.icon(toast.n)
                        size: Math.round(18 * Config.scale)
                        visible: toast.portrait
                    }
                }

                Column {
                    width: parent.width - toast.slotSize - parent.spacing
                    spacing: 2

                    Text {
                        width: parent.width - toast.closeSize
                        text: toast.n.appName
                        visible: text !== ""
                        color: toast.critical ? Theme.colors.error : Theme.colors.fgVariant
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 3
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: toast.n.summary
                        color: Theme.colors.fg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: toast.n.body
                        visible: text !== ""
                        color: Theme.colors.fgVariant
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }
                }
            }

            // Loaded once, shown as banner or portrait by shape. Hidden and square when a
            // portrait, so the Column skips it and the icon slot's MultiEffect draws it there.
            Image {
                id: picture
                width: toast.banner ? parent.width : toast.portraitSize
                height: toast.banner ? Math.round(120 * Config.scale) : toast.portraitSize
                source: toast.n.image
                visible: toast.banner
                sourceSize: Qt.size(512, 512)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Row {
                spacing: Math.round(8 * Config.scale)
                visible: toast.n.actions.length > (toast.defaultAction ? 1 : 0)

                Repeater {
                    model: toast.n.actions

                    Rectangle {
                        required property var modelData

                        width: label.width + 24
                        height: Math.round(28 * Config.scale)
                        radius: height / 2
                        color: Theme.colors.surfaceContainerHigh
                        visible: modelData.identifier !== "default"

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Theme.colors.primary
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                        }

                        StateLayer {
                            radius: parent.radius
                            hovered: actionHover.hovered
                        }

                        HoverHandler {
                            id: actionHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
