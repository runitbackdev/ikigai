import QtQuick
import Ikigai.Input

// A card that asks one user for a password: avatar, name, the field, a Caps Lock
// warning while it is on, a message line, then whatever the host adds below. Enter or
// the arrow submits; `reject` shakes the card, clears the field and shows why. `shown`
// false fades it out, for a host that goes away.
Item {
    id: card

    property var user: null
    property bool busy: false
    property string message: ""
    property string subtitle: ""
    property bool shown: true
    default property alias extra: extraSlot.data

    signal submit(string password)

    readonly property int pad: Math.round(28 * Config.scale)
    readonly property int fieldWidth: Math.round(280 * Config.scale)

    implicitWidth: body.width + 48
    implicitHeight: body.height + 48

    function reject(why) {
        message = why;
        busy = false;
        password.text = "";
        shake.restart();
    }

    function clear() {
        password.text = "";
        message = "";
    }

    // A Loader only routes focus once it has it itself; claim it outright so the field
    // types without a click on both the greeter and the lock surface.
    Component.onCompleted: password.forceActiveFocus()

    // The last message stays, dimmed, until the answer: cleared here it would close and
    // open again on every wrong password.
    function trySubmit() {
        if (!user || busy || password.text === "")
            return;
        busy = true;
        submit(password.text);
    }

    SequentialAnimation {
        id: shake
        loops: 3
        NumberAnimation { target: body; property: "anchors.horizontalCenterOffset"; to: -8; duration: 40 }
        NumberAnimation { target: body; property: "anchors.horizontalCenterOffset"; to: 8; duration: 80 }
        NumberAnimation { target: body; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
    }

    DialogCard {
        id: body
        anchors.centerIn: parent
        pad: card.pad
        shown: card.shown

        Column {
            id: column
            spacing: Math.round(16 * Config.scale)

            Avatar {
                anchors.horizontalCenter: parent.horizontalCenter
                user: card.user
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.user ? card.user.fullName : ""
                color: Theme.colors.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 1.5
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: card.fieldWidth
                text: card.subtitle
                visible: card.subtitle !== ""
                color: Theme.colors.fgVariant
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            // The notes under the field carry their own gap, so a closed one takes no
            // spacing and the card grows and shrinks with them instead of snapping.
            Column {
                width: card.fieldWidth

                Rectangle {
                    width: card.fieldWidth
                    height: Math.round(44 * Config.scale)
                    radius: Theme.radius
                    color: Theme.colors.surfaceContainerHigh
                    border.width: 1
                    border.color: password.activeFocus ? Theme.colors.primary : Theme.colors.outlineVariant
                    opacity: card.busy ? 0.6 : 1

                    Behavior on border.color {
                        ColorAnim {}
                    }

                    TextInput {
                        id: password
                        anchors {
                            left: parent.left
                            right: go.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 14
                        }
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.colors.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 1.1
                        focus: true
                        enabled: !card.busy
                        clip: true
                        Keys.onReturnPressed: card.trySubmit()
                        Keys.onEnterPressed: card.trySubmit()
                        Keys.onEscapePressed: card.clear()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password"
                            color: Theme.colors.outline
                            font: password.font
                            visible: password.text === ""
                        }
                    }

                    BarButton {
                        id: go
                        anchors {
                            right: parent.right
                            rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        onClicked: card.trySubmit()

                        Glyph {
                            anchors.centerIn: parent
                            name: "arrow-right"
                            size: 18
                            color: password.text === "" ? Theme.colors.outline : Theme.colors.primary
                        }
                    }
                }

                DialogReveal {
                    width: parent.width
                    gap: column.spacing
                    shown: Keyboard.capsLock

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "arrow-fat-line-up"
                            size: 16
                            color: Theme.colors.warning
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Caps Lock is on"
                            color: Theme.colors.warning
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }

                DialogReveal {
                    width: parent.width
                    gap: column.spacing
                    shown: card.message !== ""

                    Text {
                        id: note
                        width: parent.width
                        opacity: card.busy ? 0.6 : 1
                        color: Theme.colors.error
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    // Held through the close, so the line fades with its words in it.
                    Binding {
                        target: note
                        property: "text"
                        value: card.message
                        when: card.message !== ""
                        restoreMode: Binding.RestoreNone
                    }
                }
            }

            Column {
                id: extraSlot
                width: card.fieldWidth
                spacing: Math.round(16 * Config.scale)
            }
        }
    }
}
