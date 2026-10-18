import QtQuick

// Text in the shell's face and size, whose colour cross-fades like Glyph's: for labels
// that change colour with a state (a selected row, a muted device).
Text {
    color: Theme.colors.fg
    font.family: Theme.fontFamily
    font.pointSize: Theme.fontSize

    Behavior on color {
        ColorAnim {}
    }
}
