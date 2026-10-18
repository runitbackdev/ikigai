import QtQuick

// Colours take the slow effects curve, as caelestia's do: a tint change is a state change
// the eye should follow, slower than the opacity fades around it.
ColorAnimation {
    duration: Motion.slowEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.slowEffectsCurve
}
