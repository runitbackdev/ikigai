import QtQuick
import QtQuick.Controls.impl

// An icon by name, coloured like text. Phosphor names draw from the font; "brand:<name>"
// draws icons/brand/<name>.svg, hand-drawn marks in Phosphor's grammar. `fill` switches
// to the filled weight of either.
Item {
    id: glyph

    property string name: "question"
    property int size: 16
    property bool fill: false
    property color color: Theme.colors.fg

    readonly property bool brand: name.startsWith("brand:")

    implicitWidth: size
    implicitHeight: size

    Text {
        anchors.centerIn: parent
        visible: !glyph.brand
        text: glyph.brand ? "" : Icons.glyph(glyph.name)
        color: glyph.color
        font.family: glyph.fill ? Theme.iconFillFont : Theme.iconFont
        font.pixelSize: glyph.size
    }

    // Only for brand marks: an IconImage with no source still runs a theme lookup for the
    // empty name on creation, a miss that walks every icon directory (tens of ms without
    // an icon-theme.cache), and would do so for every font glyph.
    Loader {
        anchors.fill: parent
        active: glyph.brand

        sourceComponent: IconImage {
            source: Qt.resolvedUrl("icons/brand/" + glyph.name.slice(6) + (glyph.fill ? "-fill" : "") + ".svg")
            sourceSize: Qt.size(glyph.size * 2, glyph.size * 2)
            color: glyph.color
        }
    }
}
