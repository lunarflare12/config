pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io

// Watches screen recorders and can stop them from the center island.
Singleton {
    id: root

    property bool recording: false

    function stop() {
        Quickshell.execDetached(["pkill", "-x", "wf-recorder"]);
        Quickshell.execDetached(["pkill", "-x", "gpu-screen-recorder"]);
        Quickshell.execDetached(["pkill", "-x", "wl-screenrec"]);
        root.recording = false;
    }

    Process {
        id: probe

        command: ["pidof", "wf-recorder", "gpu-screen-recorder", "wl-screenrec"]

        stdout: StdioCollector {
            onStreamFinished: root.recording = this.text.trim().length > 0
        }

        onExited: function (exitCode) {
            if (exitCode !== 0)
                root.recording = false;
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
    }
}
