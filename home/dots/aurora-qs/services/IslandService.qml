pragma Singleton

import QtQuick
import Quickshell

// Faces on the center island. Super+wheel turns them like a gear tooth.
Item {
    id: root
    visible: false

    property bool music: false
    property bool recording: false
    readonly property int count: 1 + (root.music ? 1 : 0) + (root.recording ? 1 : 0)

    function sync(music, recording) {
        if (root.music !== music)
            root.music = music;
        if (root.recording !== recording)
            root.recording = recording;
    }

    property string kind: "clock"
    property string nextKind: "clock"
    property int direction: 1
    property real gear: 0
    property bool busy: false

    function list() {
        const out = ["clock"];
        if (root.music)
            out.push("music");
        if (root.recording)
            out.push("recording");
        return out;
    }

    function cycle(dir) {
        const faces = root.list();
        if (faces.length < 2 || root.busy)
            return;
        let index = faces.indexOf(root.kind);
        if (index < 0)
            index = 0;
        root.direction = dir < 0 ? -1 : 1;
        root.nextKind = faces[(index + root.direction + faces.length) % faces.length];
        root.busy = true;
        root.gear = 0;
        gearAnim.restart();
    }

    function showNew(id) {
        if (root.busy) {
            gearAnim.stop();
            root.gear = 0;
            root.busy = false;
        }
        root.kind = id;
        root.nextKind = id;
    }

    onMusicChanged: {
        if (root.music)
            root.showNew("music");
        else if (root.kind === "music" || root.nextKind === "music")
            root.showNew(root.recording ? "recording" : "clock");
    }

    onRecordingChanged: {
        if (root.recording)
            root.showNew("recording");
        else if (root.kind === "recording" || root.nextKind === "recording")
            root.showNew(root.music ? "music" : "clock");
    }

    NumberAnimation {
        id: gearAnim
        target: root
        property: "gear"
        from: 0
        to: 1
        duration: 560
        easing.type: Easing.OutCubic
        onFinished: {
            root.kind = root.nextKind;
            root.gear = 0;
            root.busy = false;
        }
    }
}
