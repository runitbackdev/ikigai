import QtQuick

// Content of a popout. Sized by implicitWidth/Height; Popouts fits its frame to whichever
// content is current and cross-fades between them. `done` asks the host to close.
Item {
    property var task: null
    property bool shown: false
    default property alias content: body.data
    // What the card's own blob covers, and further panels beside it (a menu's open
    // submenus), in the card's coordinates. By default the whole card and nothing else.
    property real baseWidth: implicitWidth
    property real baseHeight: implicitHeight
    property var panels: []

    signal done

    width: implicitWidth
    height: implicitHeight
    opacity: shown ? 1 : 0
    visible: opacity > 0

    Item {
        id: body
        anchors {
            fill: parent
            margins: 6
        }
    }

    Behavior on opacity {
        Anim { effects: true; fast: true }
    }
}
