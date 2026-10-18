import Quickshell
import QtQuick

// Stacked clock for a narrow rail: hours over minutes, AM/PM and the date beneath. Click opens the
// sidebar; a badge counts notifications not yet seen there.
Item {
    id: root

    required property ShellScreen screen

    implicitWidth: Theme.barWidth
    implicitHeight: column.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    StateLayer {
        hovered: hover.hovered
        active: Notifs.sidebarScreen === root.screen
    }

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (clock.date.getHours() + 11) % 12 + 1
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "mm")
            color: Theme.colors.fg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "AP")
            color: Theme.colors.fgVariant
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 4
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 4
            text: Qt.formatDate(clock.date, "MMM d")
            color: Theme.colors.fgVariant
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
        }
    }

    // Grows in on the first unread and shrinks away once the sidebar has been seen. It
    // keeps the last count while it shrinks, rather than showing a 0 on the way out.
    Rectangle {
        readonly property int unread: Notifs.unread
        property int count: unread

        onUnreadChanged: if (unread > 0) count = unread

        anchors {
            top: parent.top
            right: parent.right
            topMargin: -14
            rightMargin: 0
        }
        width: Math.max(height, badge.implicitWidth + 8)
        height: Math.round(16 * Config.scale)
        radius: height / 2
        color: Theme.colors.primary
        visible: opacity > 0
        scale: unread > 0 ? 1 : 0
        opacity: unread > 0 ? 1 : 0

        Behavior on scale {
            Anim { fast: true }
        }

        Behavior on opacity {
            Anim { effects: true }
        }

        Text {
            id: badge
            anchors.centerIn: parent
            text: parent.count > 99 ? "99+" : parent.count
            color: Theme.colors.primaryFg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 4
            font.bold: true
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Notifs.toggleSidebar(root.screen)
    }
}
