pragma Singleton

import QtQuick

import Quickshell
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

    readonly property bool available: root.active !== null

    readonly property bool playing: root.available && root.active.playbackState === MprisPlaybackState.Playing

    // Track info

    readonly property string title: root.available ? String(root.active.trackTitle || "") : ""

    readonly property string artist: root.available ? String(root.active.trackArtist || "") : ""

    readonly property string identity: root.available ? String(root.active.identity || "") : ""

    readonly property string album: root.available ? String(root.active.trackAlbum || "") : ""

    readonly property string desktopEntry: root.available ? String(root.active.desktopEntry || "") : ""

    readonly property string artUrl: root.available ? String(root.active.trackArtUrl || "") : ""

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
        if (!root.available || !root.active.lengthSupported)
            return 0;
        const n = Number(root.active.length);
        return isFinite(n) && n > 0 ? n : 0;
    }

    readonly property bool positionSupported: root.available && root.active.positionSupported

    readonly property bool lengthSupported: root.available && root.active.lengthSupported && root.length > 0

    readonly property real progress: root.length > 0 ? Math.max(0, Math.min(1, root.position / root.length)) : 0

    // Controls
    //
    // Guarded individually: MPRIS compliance varies wildly by player, so the
    // canXyz flags are the only safe way to call any of this.

    readonly property bool canToggle: root.available && root.active.canTogglePlaying

    readonly property bool canNext: root.available && root.active.canGoNext

    readonly property bool canPrevious: root.available && root.active.canGoPrevious

    readonly property bool canSeek: root.available && root.active.canSeek && root.lengthSupported

    readonly property bool canRaise: root.available && root.active.canRaise

    function pullPosition() {
        if (!root.available || !root.active.positionSupported) {
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
        if (root.canToggle)
            root.active.togglePlaying();
    }

    function next() {
        if (root.canNext)
            root.active.next();
    }

    function previous() {
        if (root.canPrevious)
            root.active.previous();
    }

    function seekTo(ratio) {
        if (!root.canSeek)
            return;
        const t = Math.max(0, Math.min(1, Number(ratio))) * root.length;
        root.active.position = t;
        root.position = t;
    }

    function raise() {
        if (root.canRaise)
            root.active.raise();
    }

    onActiveChanged: root.pullPosition()
    onPlayingChanged: root.pullPosition()
    onArtUrlChanged: root.pullPosition()

    Timer {
        interval: 500
        running: root.available && root.positionSupported
        repeat: true
        onTriggered: root.pullPosition()
    }
}
