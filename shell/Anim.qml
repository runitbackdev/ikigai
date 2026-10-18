import QtQuick

// One animation type for the shell: spatial by default, `effects` for fades, `standard`
// for things that must not overshoot (a border that shrinks to its minimum). `fast` and
// `slow` pick the neighbouring token: slow for the bigger reveals, fast for tiny marks.
NumberAnimation {
    property bool effects: false
    property bool standard: false
    property bool fast: false
    property bool slow: false

    duration: standard ? Motion.standard : effects ? (fast ? Motion.fastEffects : slow ? Motion.slowEffects : Motion.defaultEffects) : (fast ? Motion.fastSpatial : slow ? Motion.slowSpatial : Motion.defaultSpatial)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: standard ? Motion.standardCurve : effects ? (fast ? Motion.fastEffectsCurve : slow ? Motion.slowEffectsCurve : Motion.defaultEffectsCurve) : (fast ? Motion.fastSpatialCurve : slow ? Motion.slowSpatialCurve : Motion.defaultSpatialCurve)
}
