pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// MprisService
//
// Thin wrapper around the MPRIS players Quickshell exposes over D-Bus.
//
// Everything the bar needs is flattened into plain properties (available /
// playing / title / artist) so NowPlaying.qml stays a pure view and never has
// to import the Mpris module or reach into Mpris.players itself.

Singleton {
    id: root

    // Players

    readonly property var players: (Mpris.players && Mpris.players.values) ? Mpris.players.values : []

    readonly property string bridgeBin: (Quickshell.env("HOME") || "") + "/.config/scripts/mpris-bridge.py"

    property var bridge: ({
        "available": false,
        "playing": false,
        "title": "",
        "artist": "",
        "album": "",
        "identity": "",
        "desktopEntry": "",
        "artUrl": "",
        "length": 0,
        "position": 0,
        "canToggle": false,
        "canNext": false,
        "canPrevious": false,
        "canSeek": false,
        "canRaise": false
    })

    // Active player
    //
    // Prefers whatever is actually playing, then whatever carries track
    // metadata, then simply the first player that registered. Browsers publish
    // a player per tab, so picking blindly would happily show a paused YouTube
    // tab while Spotify is the thing making noise.

    readonly property var active: {
        const list = root.players;

        for (let i = 0; i < list.length; i++) {
            const p = list[i];

            if (p && p.playbackState === MprisPlaybackState.Playing)
                return p;
        }

        for (let i = 0; i < list.length; i++) {
            const p = list[i];

            if (p && String(p.trackTitle || "") !== "")
                return p;
        }

        return list.length > 0 ? list[0] : null;
    }

    readonly property bool hostPlaying: root.active !== null && root.active.playbackState === MprisPlaybackState.Playing

    readonly property bool useBridge: {
        if (root.hostPlaying)
            return false;
        if (root.bridge && root.bridge.playing)
            return true;
        if (root.active && String(root.active.trackTitle || "") !== "")
            return false;
        return !!(root.bridge && root.bridge.available);
    }

    readonly property bool available: root.useBridge ? !!root.bridge.available : root.active !== null

    readonly property bool playing: root.useBridge ? !!root.bridge.playing : root.hostPlaying

    // Track info

    readonly property string title: root.useBridge ? String(root.bridge.title || "") : (root.active ? String(root.active.trackTitle || "") : "")

    readonly property string artist: root.useBridge ? String(root.bridge.artist || "") : (root.active ? String(root.active.trackArtist || "") : "")

    readonly property string identity: root.useBridge ? String(root.bridge.identity || "") : (root.active ? String(root.active.identity || "") : "")

    readonly property string album: root.useBridge ? String(root.bridge.album || "") : (root.active ? String(root.active.trackAlbum || "") : "")

    readonly property string desktopEntry: root.useBridge ? String(root.bridge.desktopEntry || "") : (root.active ? String(root.active.desktopEntry || "") : "")

    readonly property string artUrl: root.useBridge ? String(root.bridge.artUrl || "") : (root.active ? String(root.active.trackArtUrl || "") : "")

    readonly property string artSource: {
        const u = root.artUrl;
        if (!u)
            return "";
        if (u.indexOf("://") >= 0)
            return u;
        if (u.charAt(0) === "/")
            return "file://" + u;
        return u;
    }

    // What the bar prints.
    //
    // Falls back to the player name so the module never shows an empty label
    // while a stream is still resolving its metadata.
    readonly property string label: {
        if (!root.available)
            return "";

        if (root.title !== "")
            return root.title;

        if (root.identity !== "")
            return root.identity;

        return "Playing";
    }

    readonly property string playerLabel: {
        if (root.identity !== "")
            return root.identity;
        if (root.desktopEntry !== "")
            return root.desktopEntry;
        return "Player";
    }

    // Position is not a live NOTIFY on most players. Copy it on a timer while
    // something is loaded so the desktop widget can draw a scrubber.
    property real position: 0

    readonly property real length: {
        if (root.useBridge) {
            const n = Number(root.bridge.length || 0);
            return isFinite(n) && n > 0 ? n : 0;
        }
        if (!root.active || !root.active.lengthSupported)
            return 0;
        const n = Number(root.active.length);
        return isFinite(n) && n > 0 ? n : 0;
    }

    readonly property bool positionSupported: root.useBridge ? root.length > 0 : (root.available && root.active && root.active.positionSupported)

    readonly property bool lengthSupported: root.length > 0

    readonly property real progress: root.length > 0 ? Math.max(0, Math.min(1, root.position / root.length)) : 0

    // Controls
    //
    // Guarded individually: MPRIS compliance varies wildly by player, so the
    // canXyz flags are the only safe way to call any of this.

    readonly property bool canToggle: root.useBridge ? !!root.bridge.canToggle : (root.available && root.active && root.active.canTogglePlaying)

    readonly property bool canNext: root.useBridge ? !!root.bridge.canNext : (root.available && root.active && root.active.canGoNext)

    readonly property bool canPrevious: root.useBridge ? !!root.bridge.canPrevious : (root.available && root.active && root.active.canGoPrevious)

    readonly property bool canSeek: root.useBridge ? !!root.bridge.canSeek && root.lengthSupported : (root.available && root.active && root.active.canSeek && root.lengthSupported)

    readonly property bool canRaise: !root.useBridge && root.available && root.active && root.active.canRaise

    function bridgeCtl(action, extra) {
        const args = ["python3", root.bridgeBin, String(action)];
        if (extra !== undefined && extra !== null && String(extra) !== "")
            args.push(String(extra));
        Quickshell.execDetached(args);
    }

    function ingestBridge(line) {
        try {
            const next = JSON.parse(line);
            if (!next || typeof next !== "object")
                return;
            root.bridge = next;
            if (root.useBridge)
                root.position = Number(next.position || 0);
        } catch (e) {}
    }

    function pullPosition() {
        if (root.useBridge) {
            root.position = Number(root.bridge.position || 0);
            return;
        }
        if (!root.available || !root.active || !root.active.positionSupported) {
            root.position = 0;
            return;
        }
        const n = Number(root.active.position);
        if (!isFinite(n) || n < 0) {
            root.position = 0;
            return;
        }
        root.position = root.length > 0 ? Math.min(n, root.length) : n;
    }

    function formatTime(secs) {
        if (!isFinite(secs) || secs < 0)
            return "--:--";
        const total = Math.floor(secs);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        function pad(n) {
            return (n < 10 ? "0" : "") + n;
        }
        if (h > 0)
            return h + ":" + pad(m) + ":" + pad(s);
        return m + ":" + pad(s);
    }

    function toggle() {
        if (!root.canToggle)
            return;
        if (root.useBridge)
            root.bridgeCtl("toggle");
        else
            root.active.togglePlaying();
    }

    function next() {
        if (!root.canNext)
            return;
        if (root.useBridge)
            root.bridgeCtl("next");
        else
            root.active.next();
    }

    function previous() {
        if (!root.canPrevious)
            return;
        if (root.useBridge)
            root.bridgeCtl("previous");
        else
            root.active.previous();
    }

    function seekTo(ratio) {
        if (!root.canSeek)
            return;
        const t = Math.max(0, Math.min(1, Number(ratio))) * root.length;
        if (root.useBridge) {
            root.bridgeCtl("seek", String(Math.max(0, Math.min(1, Number(ratio)))));
            root.position = t;
            return;
        }
        root.active.position = t;
        root.position = t;
    }

    function raise() {
        if (root.canRaise)
            root.active.raise();
    }

    function raiseApp(app) {
        if (!app)
            return false;
        const needles = LaunchSplash.needlesOf(app);
        const list = root.players;
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (!p || !p.canRaise)
                continue;
            const blob = String((p.identity || "") + " " + (p.desktopEntry || "")).toLowerCase();
            if (!blob.trim())
                continue;
            let hit = false;
            for (let n = 0; n < needles.length; n++) {
                const needle = String(needles[n] || "").toLowerCase();
                if (!needle || needle.length < 4)
                    continue;
                if (needle === "chrome" || needle === "chromium")
                    continue;
                if (blob.indexOf(needle) >= 0) {
                    hit = true;
                    break;
                }
            }
            if (!hit)
                continue;
            p.raise();
            return true;
        }
        return false;
    }

    onActiveChanged: root.pullPosition()
    onPlayingChanged: root.pullPosition()
    onArtUrlChanged: root.pullPosition()

    Timer {
        interval: 500
        running: root.available && root.positionSupported && !root.useBridge
        repeat: true
        onTriggered: root.pullPosition()
    }

    Process {
        running: true
        command: ["python3", root.bridgeBin]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                root.ingestBridge(line);
            }
        }
    }
}
