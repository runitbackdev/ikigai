pragma Singleton
import Quickshell

// Numbers the way Task Manager prints them: bytes in MB and GB (base 2), percentages
// with one decimal below ten, frequencies in GHz, durations as d:hh:mm:ss.
Singleton {
    function bytes(n) {
        if (!n)
            return "0 MB";
        const gb = n / 1073741824;
        if (gb >= 10)
            return gb.toFixed(1) + " GB";
        if (gb >= 1)
            return gb.toFixed(2) + " GB";
        const mb = n / 1048576;
        if (mb < 0.05)
            return "0 MB";
        return (mb >= 10 ? mb.toFixed(0) : mb.toFixed(1)) + " MB";
    }

    function percent(v) {
        if (!v || v < 0.05)
            return "0%";
        return (v < 10 ? v.toFixed(1) : Math.round(v).toString()) + "%";
    }

    function ghz(mhz) {
        return (mhz / 1000).toFixed(2) + " GHz";
    }

    function duration(seconds) {
        const s = Math.floor(seconds);
        const d = Math.floor(s / 86400);
        const h = Math.floor(s % 86400 / 3600);
        const m = Math.floor(s % 3600 / 60);
        const two = n => n.toString().padStart(2, "0");
        return d + ":" + two(h) + ":" + two(m) + ":" + two(s % 60);
    }

    function count(n) {
        return n.toLocaleString(Qt.locale(), "f", 0);
    }
}
