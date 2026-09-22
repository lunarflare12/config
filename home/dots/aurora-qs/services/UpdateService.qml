pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: root.home + "/.config/scripts/system-update.sh"
    property bool running: false

    function start() {
        if (root.running || proc.running)
            return;
        proc.running = true;
    }

    property Process proc: Process {
        command: ["kitty", "--class", "sysupdate", "-e", root.script]
        running: false
        onRunningChanged: root.running = running
    }
}
