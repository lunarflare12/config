pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io

// CavaService

Singleton {
    id: root

    // Must match `bars` in cava.conf. level() tolerates a mismatch rather than
    // letting the strip break, but the two are meant to be edited together.
    readonly property int barCount: 32

    // cava.conf sets ascii_max_range to this, so values arrive as 0..1000.
    readonly property real range: 1000.0

    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/cava.conf"

    // Held at 0 by default. Each visual (bar EQ, desktop widget) retain()s
    // while it needs frames so cava is not decoding audio for nobody.
    property int consumers: 0

    readonly property bool enabled: root.consumers > 0

    property var values: root.silence()

    readonly property bool running: proc.running

    // Kick-drum / bass energy and a short beat flash for the now-playing card.
    property real bass: 0
    property real beat: 0
    property real _env: 0.12
    property real _prev: 0

    function retain() {
        root.consumers += 1;
    }

    function release() {
        root.consumers = Math.max(0, root.consumers - 1);
    }

    function ingest() {
        const b = Math.min(1, (root.level(0) * 1.6 + root.level(1) * 1.15 + root.level(2) * 0.55) / 3.3);
        root.bass = b;
        const e = root._env * 0.86 + b * 0.14;
        if (b > 0.22 && b > e * 1.28 && (b - root._prev) > 0.05)
            root.beat = 1;
        root._env = Math.max(0.06, e);
        root._prev = b;
    }

    function silence() {
        const out = [];

        for (let i = 0; i < root.barCount; i++) {
            out.push(0.0);
        }

        return out;
    }

    function level(i) {
        const v = root.values[i];

        return (v === undefined || isNaN(v)) ? 0.0 : v;
    }

    onEnabledChanged: {
        if (!root.enabled) {
            root.values = root.silence();
            root.bass = 0;
            root.beat = 0;
            root._env = 0.12;
            root._prev = 0;
        }
    }

    onValuesChanged: root.ingest()

    Timer {
        interval: 33
        running: root.enabled
        repeat: true
        onTriggered: root.beat = root.beat > 0.03 ? root.beat * 0.78 : 0
    }

    Process {
        id: proc

        running: root.enabled

        command: ["cava", "-p", root.configPath]

        // cava writes one frame per line as "v;v;...;v;", with a trailing bar
        // delimiter on the last value, so the split leaves an empty tail.
        stdout: SplitParser {
            splitMarker: "\n"

            onRead: function (line) {
                const parts = line.split(";");

                const out = [];

                for (let i = 0; i < parts.length; i++) {
                    if (parts[i].length === 0)
                        continue;

                    const v = parseInt(parts[i], 10);

                    out.push(isNaN(v) ? 0.0 : Math.min(1.0, v / root.range));
                }

                if (out.length > 0)
                    root.values = out;
            }
        }
    }
}
