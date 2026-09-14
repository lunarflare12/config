pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Aurora Apps Service
//
// Application list and ranking for the launcher.
// State: ~/.cache/aurora/launcher-usage.json

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string usagePath: root.home + "/.cache/aurora/launcher-usage.json"

    property var usage: ({})

    // Frecency

    property FileView usageFile: FileView {
        path: root.usagePath
        blockLoading: true
        printErrors: false
    }

    function loadUsage() {
        const raw = root.usageFile.text()
        if (!raw) {
            root.usage = ({})
            return
        }

        try {
            const parsed = JSON.parse(raw)
            root.usage = (parsed && typeof parsed === "object") ? parsed : ({})
        } catch (e) {
            root.usage = ({})
        }
    }

    function bump(id) {
        if (!id || id.length === 0)
            return

        // Copy, then mutate, then assign.
        const next = ({})
        const keys = Object.keys(root.usage)

        for (let i = 0; i < keys.length; i++)
            next[keys[i]] = root.usage[keys[i]]

        next[id] = (next[id] || 0) + 1
        root.usage = next

        root.usageFile.setText(JSON.stringify(next))
    }

    // Entries

    property var entries: []

    readonly property var rawApps: DesktopEntries.applications.values

    onRawAppsChanged: root.rebuildEntries()

    readonly property string finderIcon: "file://" + Quickshell.shellDir + "/assets/finder-icon.png"
    readonly property string keymappIcon: "file://" + Quickshell.shellDir + "/assets/keymapp.png"
    readonly property string sattyIcon: "file://" + Quickshell.shellDir + "/assets/satty.png"

    function haystack(entry) {
        return [
            entry.id,
            entry.name,
            entry.execString,
            entry.startupClass
        ].join(" ").toLowerCase()
    }

    function isGuiApp(entry) {
        if (entry.runInTerminal === true || entry.terminal === true)
            return false

        const cats = entry.categories
        if (cats) {
            for (let i = 0; i < cats.length; i++) {
                const cat = String(cats[i]).toLowerCase()
                if (cat === "consoleonly")
                    return false
            }
        }

        return true
    }

    function isJunk(entry) {
        const text = root.haystack(entry)
        const deny = [
            "kvantum",
            "qt5ct",
            "qt6ct",
            "qv4l2",
            "qvidcap",
            "nm-connection",
            "uuctl",
            "pavucontrol",
            "zathura"
        ]

        for (let i = 0; i < deny.length; i++) {
            if (text.indexOf(deny[i]) !== -1)
                return true
        }

        return false
    }

    function isFileManager(entry) {
        const text = root.haystack(entry)
        if (text.indexOf("thunar") !== -1)
            return true

        const cats = entry.categories
        if (cats) {
            for (let i = 0; i < cats.length; i++) {
                if (String(cats[i]).toLowerCase() === "filemanager")
                    return true
            }
        }

        return false
    }

    function isMainFileManager(entry) {
        const id = String(entry.id || "").toLowerCase()
        return id === "thunar" || id === "org.xfce.thunar"
    }

    function isKeymapp(entry) {
        const text = root.haystack(entry)
        return text.indexOf("keymapp") !== -1
    }

    function isSatty(entry) {
        return root.haystack(entry).indexOf("satty") !== -1
    }

    function iconSource(entry) {
        if (!entry)
            return Quickshell.iconPath("application-x-executable")
        if (root.isMainFileManager(entry))
            return root.finderIcon
        if (root.isKeymapp(entry))
            return root.keymappIcon
        if (root.isSatty(entry))
            return root.sattyIcon
        return Quickshell.iconPath(entry.icon, "application-x-executable")
    }

    function displayName(entry) {
        if (root.isMainFileManager(entry))
            return "Finder"
        return entry && entry.name ? entry.name : "App"
    }

    function steamAppId(entry) {
        const exec = String(entry && (entry.execString || entry.exec) || "").toLowerCase()
        const match = exec.match(/rungameid\/(\d+)/)
        return match ? match[1] : ""
    }

    function rebuildEntries() {
        const source = DesktopEntries.applications.values
        const out = []
        const seenSteam = {}
        const seenName = {}

        for (let i = 0; i < source.length; i++) {
            const entry = source[i]
            if (!entry)
                continue

            if (entry.noDisplay === true)
                continue

            if (!entry.name || entry.name.length === 0)
                continue

            if (!root.isGuiApp(entry))
                continue

            if (root.isJunk(entry))
                continue

            if (root.isFileManager(entry) && !root.isMainFileManager(entry))
                continue

            const steamId = root.steamAppId(entry)
            if (steamId) {
                if (seenSteam[steamId])
                    continue
                seenSteam[steamId] = true
            } else {
                const nameKey = String(entry.name).toLowerCase().replace(/®/g, "").trim()
                if (seenName[nameKey])
                    continue
                seenName[nameKey] = true
            }

            out.push(entry)
        }

        out.sort(function (a, b) {
            const an = a.name.toLowerCase()
            const bn = b.name.toLowerCase()

            if (an < bn)
                return -1

            if (an > bn)
                return 1

            return 0
        })

        const cur = root.entries
        if (cur.length === out.length) {
            let same = true
            for (let i = 0; i < out.length; i++) {
                if (cur[i].id !== out[i].id) {
                    same = false
                    break
                }
            }
            if (same)
                return
        }

        root.entries = out
    }

    readonly property int count: root.entries.length

    // Matching

    function subsequence(haystack, needle) {
        let h = 0

        for (let n = 0; n < needle.length; n++) {
            let found = false

            while (h < haystack.length) {
                if (haystack.charAt(h) === needle.charAt(n)) {
                    found = true
                    h++
                    break
                }
                h++
            }

            if (!found)
                return false
        }

        return true
    }

    // Tiers, strongest first.
    function score(entry, q) {
        const name = entry.name ? entry.name.toLowerCase() : ""

        if (name.indexOf(q) === 0)
            return 400

        const words = name.split(/[\s\-_.]+/)
        for (let i = 0; i < words.length; i++) {
            if (words[i].indexOf(q) === 0)
                return 300
        }

        if (name.indexOf(q) !== -1)
            return 200

        const generic = entry.genericName ? entry.genericName.toLowerCase() : ""
        if (generic.length > 0 && generic.indexOf(q) !== -1)
            return 140

        const comment = entry.comment ? entry.comment.toLowerCase() : ""
        if (comment.length > 0 && comment.indexOf(q) !== -1)
            return 100

        const keywords = entry.keywords
        if (keywords) {
            for (let k = 0; k < keywords.length; k++) {
                if (String(keywords[k]).toLowerCase().indexOf(q) !== -1)
                    return 100
            }
        }

        if (root.subsequence(name, q))
            return 60

        return -1
    }

    function search(query) {
        const all = root.entries

        if (!query || query.trim().length === 0) {
            const ranked = all.slice()
            ranked.sort(function (a, b) {
                const ua = root.usage[a.id] || 0
                const ub = root.usage[b.id] || 0
                if (ub !== ua)
                    return ub - ua
                const an = String(a.name || "").toLowerCase()
                const bn = String(b.name || "").toLowerCase()
                if (an < bn)
                    return -1
                if (an > bn)
                    return 1
                return 0
            })
            return ranked
        }

        const q = query.trim().toLowerCase()
        const scored = []

        for (let i = 0; i < all.length; i++) {
            const entry = all[i]
            let s = root.score(entry, q)

            if (s < 0)
                continue

            // Frecency is a tie-breaker, capped so a heavily used app can never leapfrog a genuine prefix match.
            const hits = root.usage[entry.id] || 0
            s += Math.min(50, hits * 6)

            scored.push({ "entry": entry, "score": s, "index": i })
        }

        scored.sort(function (a, b) {
            if (b.score !== a.score)
                return b.score - a.score

            return a.index - b.index
        })

        const out = []
        for (let j = 0; j < scored.length; j++)
            out.push(scored[j].entry)

        return out
    }

    // Actions

    function launch(entry) {
        if (!entry)
            return

        root.bump(entry.id)
        entry.execute()
    }

    function steamIdFromClass(cls) {
        const m = String(cls || "").match(/steam_app_(\d+)/i);
        return m ? m[1] : "";
    }

    function entryForSteamId(appid) {
        const id = String(appid || "");
        if (!id)
            return null;
        const entries = root.entries;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e && root.steamAppId(e) === id)
                return e;
        }
        return null;
    }

    function entryForTitle(title) {
        const t = String(title || "").toLowerCase().replace(/®/g, "").trim();
        if (t.length < 4)
            return null;
        const entries = root.entries;
        let best = null;
        let bestLen = 0;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (!e)
                continue;
            const name = String(e.name || "").toLowerCase().replace(/®/g, "").trim();
            if (name.length < 4)
                continue;
            if (name === t)
                return e;
            if (t.indexOf(name) !== -1 || name.indexOf(t) !== -1) {
                const n = Math.min(name.length, t.length);
                if (n > bestLen) {
                    bestLen = n;
                    best = e;
                }
            }
        }
        return bestLen >= 4 ? best : null;
    }

    function entryForClass(cls) {
        const needle = String(cls || "").toLowerCase().trim();
        if (!needle)
            return null;
        if (needle.indexOf("gamescope") !== -1)
            return null;

        const entries = root.entries;
        let best = null;
        let bestScore = 0;

        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (!e)
                continue;
            const id = String(e.id || "").toLowerCase();
            const start = String(e.startupWmClass || e.startupClass || e.wmClass || "").toLowerCase();
            const icon = String(e.icon || "").toLowerCase();
            const name = String(e.name || "").toLowerCase().replace(/\s+/g, "");
            const exec = String(e.execString || e.exec || "").toLowerCase();
            let score = 0;
            if (start && (start === needle || needle === start))
                score = 100;
            else if (id && (id === needle || id === needle.replace(/-/g, ".")))
                score = 90;
            else if (icon && icon === needle)
                score = 80;
            else if (start && start.length >= 4 && (needle === start || needle.indexOf(start) === 0 || start.indexOf(needle) === 0))
                score = 70;
            else if (id && id.length >= 4 && (id === needle || needle.indexOf(id) === 0))
                score = 60;
            else if (name && name.length >= 4 && name === needle.replace(/-/g, ""))
                score = 50;
            if (score > bestScore) {
                bestScore = score;
                best = e;
            }
        }

        return best;
    }

    function gameAssetIcon(blob) {
        const s = String(blob || "").toLowerCase();
        if (s.indexOf("overwatch") !== -1 || s.indexOf("2357570") !== -1)
            return "file://" + Quickshell.shellDir + "/assets/games/overwatch.png";
        if (s.indexOf("paladin") !== -1 || s.indexOf("444090") !== -1)
            return "file://" + Quickshell.shellDir + "/assets/games/paladins.png";
        if (s.indexOf("terraria") !== -1 || s.indexOf("105600") !== -1)
            return "file://" + Quickshell.shellDir + "/assets/games/terraria.png";
        return "";
    }

    function iconFromEntry(entry) {
        if (!entry)
            return "";
        if (root.isMainFileManager(entry))
            return root.finderIcon;
        if (root.isKeymapp(entry))
            return root.keymappIcon;
        if (root.isSatty(entry))
            return root.sattyIcon;
        if (entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable");
        return "";
    }

    function iconPathForClass(cls, title) {
        const clsStr = String(cls || "");
        const titleStr = String(title || "");
        const needle = clsStr.toLowerCase();
        const asset = root.gameAssetIcon(clsStr + " " + titleStr);
        if (asset)
            return asset;

        const steamId = root.steamIdFromClass(clsStr);
        if (steamId) {
            const fromSteam = root.iconFromEntry(root.entryForSteamId(steamId));
            if (fromSteam)
                return fromSteam;
            return Quickshell.iconPath("steam_icon_" + steamId, "steam");
        }

        if (needle.indexOf("gamescope") !== -1) {
            const fromTitle = root.iconFromEntry(root.entryForTitle(titleStr));
            if (fromTitle)
                return fromTitle;
            return Quickshell.iconPath("input-gaming", "application-x-executable");
        }

        const entry = root.entryForClass(clsStr) || root.entryForTitle(titleStr);
        const fromEntry = root.iconFromEntry(entry);
        if (fromEntry)
            return fromEntry;
        if (needle.indexOf("keymapp") !== -1)
            return root.keymappIcon;
        if (needle.indexOf("satty") !== -1)
            return root.sattyIcon;
        if (needle)
            return Quickshell.iconPath(needle, "application-x-executable");
        return Quickshell.iconPath("application-x-executable");
    }

    function iconPathForWindow(t) {
        if (!t)
            return Quickshell.iconPath("application-x-executable");
        const ipc = t.lastIpcObject || {};
        return root.iconPathForClass(ipc.class || ipc.initialClass || ipc.initial_class || "", t.title || ipc.title || "");
    }

    function nameForClass(cls, fallback) {
        const entry = root.entryForClass(cls);
        if (entry && root.isMainFileManager(entry))
            return "Finder";
        if (entry && entry.name)
            return entry.name;
        return fallback || cls || "Window";
    }

    Component.onCompleted: {
        root.loadUsage()
        root.rebuildEntries()
    }
}
