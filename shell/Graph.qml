import QtQuick

// A utilization graph the way Task Manager draws one: a faint grid, the newest value at
// the right edge, the line filled down to the axis. `values` are 0..1, oldest first, up
// to `capacity` of them; fewer leave the left empty.
Canvas {
    id: graph

    property var values: []
    property int capacity: 60
    property color color: Theme.colors.primary
    property bool grid: true
    property real lineWidth: 1.5

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const w = width;
        const h = height;
        ctx.reset();
        ctx.clearRect(0, 0, w, h);

        if (grid) {
            ctx.strokeStyle = Qt.alpha(color, 0.18);
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

        const n = values.length;
        if (n === 0)
            return;
        const step = w / Math.max(1, capacity - 1);
        const x0 = w - step * (n - 1);
        const yOf = v => h - Math.max(0, Math.min(1, v)) * (h - lineWidth) - lineWidth / 2;

        ctx.beginPath();
        ctx.moveTo(x0, yOf(values[0]));
        for (let i = 1; i < n; i++)
            ctx.lineTo(x0 + step * i, yOf(values[i]));
        ctx.lineTo(w, h);
        ctx.lineTo(x0, h);
        ctx.closePath();
        ctx.fillStyle = Qt.alpha(color, 0.22);
        ctx.fill();

        ctx.beginPath();
        ctx.moveTo(x0, yOf(values[0]));
        for (let i = 1; i < n; i++)
            ctx.lineTo(x0 + step * i, yOf(values[i]));
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.stroke();
    }
}
