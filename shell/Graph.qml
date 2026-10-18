import QtQuick

// A utilization graph the way Task Manager draws one: a faint grid, the newest value at
// the right edge, the line filled down to the axis. `values` are 0..1, oldest first, up
// to `capacity` of them across the frame plus one more, the oldest, which is the one
// sliding off the left edge; fewer leave the left empty. The curve scrolls rather than
// stepping: it is painted one step wider than the frame and slid left by that step over
// `interval`, the time to the next sample, so each sample paints once and the motion in
// between is only the item moving.
Item {
    id: graph

    property var values: []
    property int capacity: 60
    property int interval: 1000
    property color color: Theme.colors.primary
    property bool grid: true
    property real lineWidth: 1.5

    readonly property real step: width / Math.max(1, capacity - 1)

    clip: true

    // The grid holds still while the curve moves over it.
    Canvas {
        id: lines
        anchors.fill: parent
        visible: graph.grid

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: graph
            function onColorChanged() { lines.requestPaint(); }
        }

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            ctx.reset();
            ctx.clearRect(0, 0, w, h);
            ctx.strokeStyle = Qt.alpha(graph.color, 0.18);
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (let i = 1; i < 10; i++) {
                const x = Math.round(w * i / 10) + 0.5;
                ctx.moveTo(x, 0);
                ctx.lineTo(x, h);
            }
            for (let i = 1; i < 4; i++) {
                const y = Math.round(h * i / 4) + 0.5;
                ctx.moveTo(0, y);
                ctx.lineTo(w, y);
            }
            ctx.stroke();
        }
    }

    // Painted with the newest value at its right edge, one step past the frame's; at x 0
    // the previous value sits on the frame's edge, where the last slide left it.
    Canvas {
        id: curve
        width: parent.width + graph.step
        height: parent.height

        // Only a new sample restarts the slide; a resize or a colour change repaints in place.
        property bool fresh: false

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: graph
            function onValuesChanged() {
                curve.fresh = true;
                curve.requestPaint();
            }
            function onColorChanged() { curve.requestPaint(); }
        }

        // Linear and as long as a sample: the curve has to arrive as the next one lands.
        NumberAnimation {
            id: slide
            target: curve
            property: "x"
            from: 0
            to: -graph.step
            duration: graph.interval
        }

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            const lw = graph.lineWidth;
            const values = graph.values;
            ctx.reset();
            ctx.clearRect(0, 0, w, h);

            // Restarted here rather than on the change, so the jump back to x 0 lands on
            // the same frame as the paint that shifted the curve.
            if (fresh) {
                fresh = false;
                slide.restart();
            }

            const n = values.length;
            if (n === 0)
                return;
            const step = graph.step;
            const x0 = w - step * (n - 1);
            const yOf = v => h - Math.max(0, Math.min(1, v)) * (h - lw) - lw / 2;

            ctx.beginPath();
            ctx.moveTo(x0, yOf(values[0]));
            for (let i = 1; i < n; i++)
                ctx.lineTo(x0 + step * i, yOf(values[i]));
            ctx.lineTo(w, h);
            ctx.lineTo(x0, h);
            ctx.closePath();
            ctx.fillStyle = Qt.alpha(graph.color, 0.22);
            ctx.fill();

            ctx.beginPath();
            ctx.moveTo(x0, yOf(values[0]));
            for (let i = 1; i < n; i++)
                ctx.lineTo(x0 + step * i, yOf(values[i]));
            ctx.strokeStyle = graph.color;
            ctx.lineWidth = lw;
            ctx.lineJoin = "round";
            ctx.stroke();
        }
    }
}
