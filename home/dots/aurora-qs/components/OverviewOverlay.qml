import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    visible: Core.Session.overviewOpen || root.intro > 0.01

    property int previewLocal: 1
    property real intro: Core.Session.overviewOpen ? 1 : 0

    readonly property var hyprMonitor: Hyprland.monitorFor(root.screen)
    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property int base: Core.Session.monitorIndex(root.monitorName) * Core.Session.workspacesPerMonitor
    readonly property int count: Core.Session.workspacesPerMonitor
    readonly property int monitorW: root.hyprMonitor ? root.hyprMonitor.width : (root.screen ? root.screen.width : 1920)
    readonly property int monitorH: root.hyprMonitor ? root.hyprMonitor.height : (root.screen ? root.screen.height : 1080)
    readonly property int monitorX: root.hyprMonitor ? root.hyprMonitor.x : 0
    readonly property int monitorY: root.hyprMonitor ? root.hyprMonitor.y : 0
    readonly property int activeGlobal: {
        const _ = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values.length : 0;
        return Core.Session.activeWorkspaceOnMonitor(root.monitorName);
    }
    readonly property var spaceLocals: {
        const _ws = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values.length : 0;
        const _tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0;
        const _ord = Core.Session.spaceOrder;
        const _rev = Core.Session.spaceRev;
        const list = Core.Session.workspaceLocalsOnMonitor(root.monitorName);
        const seen = {};
        const out = [];
        for (let i = 0; i < list.length; i++) {
            seen[list[i]] = true;
            out.push(list[i]);
        }
        if (root.previewLocal >= 1 && root.previewLocal <= root.count && !seen[root.previewLocal])
            out.push(root.previewLocal);
        return out.length ? out : [1];
    }
    readonly property int spaceRev: Core.Session.spaceRev
    onSpaceRevChanged: root.rebuildSpaces()
    onSpaceLocalsChanged: root.rebuildSpaces()

    function rebuildSpaces() {
        if (!spaceModel)
            return;
        const list = root.spaceLocals;
        spaceModel.clear();
        for (let i = 0; i < list.length; i++)
            spaceModel.append({ "ws": list[i] });
    }

    Component.onCompleted: root.rebuildSpaces()
    readonly property bool canAddSpace: root.spaceLocals.length < root.count
    readonly property var previewWins: {
        const _ = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0;
        return root.windowsOn(root.base + root.previewLocal);
    }
    property bool spacesExpanded: false
    readonly property color spaceActive: "#0A84FF"
    readonly property int thumbGap: 10
    readonly property int compactGap: 32
    readonly property int plusSize: 24
    readonly property real compactBarH: 42
    readonly property real expandedBarH: root.thumbH + 48
    property real spacesBarH: root.spacesExpanded ? root.expandedBarH : root.compactBarH

    Behavior on spacesBarH {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    readonly property real thumbW: {
        const n = Math.max(1, root.spaceLocals.length);
        const avail = Math.min(root.width - 120, 1480);
        return Math.min(186, Math.max(100, Math.floor((avail - Math.max(0, n - 1) * root.thumbGap) / n)));
    }
    readonly property real thumbH: Math.round(root.thumbW * root.monitorH / Math.max(1, root.monitorW))
    readonly property real thumbScale: root.thumbW / Math.max(1, root.monitorW)
    readonly property real thumbsRowW: {
        const n = root.spaceLocals.length;
        return n * root.thumbW + Math.max(0, n - 1) * root.thumbGap;
    }
    readonly property real compactFocusCenter: {
        const _ = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0;
        const n = root.spaceLocals.length;
        let x = 0;
        for (let i = 0; i < n; i++) {
            const local = root.spaceLocals[i];
            const w = root.compactLabelW(root.spaceLabel(i, local, root.windowsOn(root.base + local)));
            if (local === Core.Session.localId(root.activeGlobal))
                return x + w / 2;
            x += w + root.compactGap;
        }
        return x / 2;
    }
    readonly property real compactRowX: Math.round(root.width / 2 - root.compactFocusCenter)
    readonly property real expandedRowX: Math.round((root.width - (root.thumbsRowW + (root.canAddSpace ? root.thumbGap + root.plusSize : 0))) / 2)
    readonly property real spacesRowX: root.spacesExpanded ? root.expandedRowX : root.compactRowX
    readonly property real plusX: root.spacesExpanded ? (root.expandedRowX + root.thumbsRowW + root.thumbGap) : (root.width - root.plusSize - 20)

    function stripFade(x, w) {
        const left = 10;
        const right = root.width - (root.canAddSpace ? 68 : 12);
        const mid = x + w / 2;
        const fadeW = Math.max(110, root.width * 0.12);
        let o = 1;
        if (mid < left + fadeW)
            o = Math.min(o, Math.max(0.06, (mid - left) / fadeW));
        if (mid > right - fadeW)
            o = Math.min(o, Math.max(0.06, (right - mid) / fadeW));
        return o;
    }
    readonly property var exposeRects: root.computeExpose(root.previewWins)
    readonly property bool pointerHere: Core.Session.overviewDrag && Core.Session.monitorAt(Core.Session.overviewDragX, Core.Session.overviewDragY) === root.monitorName

    onPointerHereChanged: {
        if (root.pointerHere)
            root.publishDrop();
    }

    Connections {
        target: Core.Session
        function onOverviewOpenChanged() {
            if (Core.Session.overviewOpen) {
                root.spacesExpanded = false;
                Core.PopupManager.close();
                root.previewLocal = Core.Session.localId(root.activeGlobal);
                root.intro = 1;
                root.rebuildSpaces();
            } else {
                root.intro = 0;
            }
        }
        function onOverviewDragXChanged() {
            if (root.pointerHere)
                root.publishDrop();
        }
        function onOverviewDragYChanged() {
            if (root.pointerHere)
                root.publishDrop();
        }
    }

    WlrLayershell.namespace: "aurora-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (!Core.Session.overviewOpen)
            return WlrKeyboardFocus.None;
        if (Core.Session.overviewDrag && Core.Session.overviewDragKind === "window")
            return WlrKeyboardFocus.None;
        const focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        if (focused)
            return focused === root.monitorName ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
        return Core.Session.monitorIndex(root.monitorName) === 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    property Region emptyMask: Region {
        width: 0
        height: 0
    }

    Item {
        id: belowBar
        anchors.fill: parent
        anchors.topMargin: Core.Theme.barHeight
    }

    property Region belowBarMask: Region {
        item: belowBar
    }

    mask: {
        if (!(Core.Session.overviewOpen || root.intro > 0.01))
            return root.emptyMask;
        return null;
    }

    function windowsOn(globalId) {
        const out = [];
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const id = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (id !== globalId)
                continue;
            out.push(t);
        }
        return out;
    }

    function computeExpose(wins) {
        const n = wins.length;
        const stageX = 40;
        const stageY = root.spacesBarH + 12;
        const stageW = Math.max(1, root.width - 80);
        const stageH = Math.max(1, root.height - stageY - 28);
        if (n === 0)
            return [];
        const out = [];
        if (n === 1) {
            const ipc = wins[0].lastIpcObject || {};
            const size = ipc.size || [root.monitorW, root.monitorH];
            const rw = Math.max(1, Number(size[0]));
            const rh = Math.max(1, Number(size[1]));
            const maxW = stageW * 0.78;
            const maxH = stageH * 0.86;
            const s = Math.min(maxW / rw, maxH / rh);
            const w = Math.max(280, rw * s);
            const h = Math.max(160, rh * s);
            out.push({
                x: stageX + (stageW - w) / 2,
                y: stageY + (stageH - h) / 2,
                w: w,
                h: h
            });
            return out;
        }
        const cols = n === 2 ? 2 : n <= 4 ? 2 : n <= 6 ? 3 : 4;
        const rows = Math.ceil(n / cols);
        const gap = 28;
        const cellW = (stageW - gap * (cols + 1)) / cols;
        const cellH = (stageH - gap * (rows + 1)) / rows;
        for (let i = 0; i < n; i++) {
            const ipc = wins[i].lastIpcObject || {};
            const size = ipc.size || [960, 540];
            const rw = Math.max(1, Number(size[0]));
            const rh = Math.max(1, Number(size[1]));
            const maxW = cellW * 0.94;
            const maxH = cellH * 0.9;
            const s = Math.min(maxW / rw, maxH / rh);
            const w = Math.max(160, rw * s);
            const h = Math.max(100, rh * s);
            const col = i % cols;
            const row = Math.floor(i / cols);
            const cx = stageX + gap + col * (cellW + gap) + cellW / 2;
            const cy = stageY + gap + row * (cellH + gap) + cellH / 2;
            out.push({
                x: cx - w / 2,
                y: cy - h / 2,
                w: w,
                h: h
            });
        }
        return out;
    }

    function spaceLabel(index, localWs, wins) {
        if (wins && wins.length === 1) {
            const t = wins[0];
            const ipc = (t && t.lastIpcObject) ? t.lastIpcObject : {};
            const title = String((t && t.title) || ipc.title || "").trim();
            const cls = String(ipc.class || ipc.initialClass || "");
            const name = Services.AppsService.nameForClass(cls, "");
            if (title && title !== name && title.length >= 3)
                return title;
            if (name)
                return name;
            if (title)
                return title;
        }
        return "Desktop " + (index + 1);
    }

    function compactLabelW(text) {
        return Math.max(64, Math.min(340, String(text || "").length * 7.8 + 18));
    }

    function monitorIndexLeft() {
        return Core.Session.monitorIndex(root.monitorName) > 0;
    }

    function monitorIndexRight() {
        return Core.Session.monitorIndex(root.monitorName) < Core.Session.monitorOrder.length - 1;
    }

    function closeOverview() {
        Core.Session.overviewOpen = false;
    }

    function activateSpace(localWs) {
        root.closeOverview();
        Core.Session.focusLocalWorkspace(root.monitorName, localWs);
    }

    function activateWindow(t) {
        root.closeOverview();
        Core.Session.focusWindow(t);
    }

    function addDesktop() {
        const used = {};
        const locals = root.spaceLocals;
        for (let i = 0; i < locals.length; i++)
            used[locals[i]] = true;
        for (let local = 1; local <= root.count; local++) {
            if (used[local])
                continue;
            root.previewLocal = local;
            Core.Session.focusLocalWorkspace(root.monitorName, local);
            return;
        }
    }

    function closeSpace(localWs) {
        if (root.spaceLocals.length <= 1)
            return;
        const dest = Core.Session.closeLocalWorkspace(root.monitorName, localWs);
        if (dest >= 1)
            root.previewLocal = dest;
    }

    function labelFor(localWs) {
        const list = root.spaceLocals;
        for (let i = 0; i < list.length; i++) {
            if (list[i] === localWs)
                return (i + 1) === 10 ? "0" : String(i + 1);
        }
        return localWs === 10 ? "0" : String(localWs);
    }

    function localAt(at) {
        const x = Number((at && at[0]) || 0);
        const y = Number((at && at[1]) || 0);
        if (x >= root.monitorX - 8)
            return [x - root.monitorX, y - root.monitorY];
        return [x, y];
    }

    function appClass(t) {
        if (!t)
            return "";
        const ipc = t.lastIpcObject || {};
        return String(ipc.class || ipc.initialClass || t.className || "");
    }

    function publishDrop() {
        if (!Core.Session.overviewDrag || !root.pointerHere)
            return;
        const gx = Core.Session.overviewDragX;
        const gy = Core.Session.overviewDragY;
        const scaleX = root.width / Math.max(1, root.monitorW);
        const scaleY = root.height / Math.max(1, root.monitorH);
        const lx = (gx - root.monitorX) * scaleX;
        const ly = (gy - root.monitorY) * scaleY;
        if (ly <= root.spacesBarH) {
            const slot = root.spaceSlotAt(lx);
            if (slot.plus)
                Core.Session.setOverviewDrop(root.monitorName, 0, true, null);
            else if (slot.localWs >= 1)
                Core.Session.setOverviewDrop(root.monitorName, slot.localWs, false, null);
            else
                Core.Session.setOverviewDrop(root.monitorName, root.previewLocal, false, null);
            return;
        }
        if (Core.Session.overviewDragKind === "space") {
            Core.Session.setOverviewDrop(root.monitorName, root.previewLocal, false, null);
            return;
        }
        const rects = root.exposeRects;
        const wins = root.previewWins;
        for (let i = 0; i < rects.length; i++) {
            const r = rects[i];
            if (lx >= r.x && lx <= r.x + r.w && ly >= r.y && ly <= r.y + r.h + 28) {
                Core.Session.setOverviewDrop(root.monitorName, root.previewLocal, false, wins[i]);
                return;
            }
        }
        Core.Session.setOverviewDrop(root.monitorName, root.previewLocal, false, null);
    }

    function spaceSlotAt(lx) {
        const n = root.spaceLocals.length;
        const gap = root.spacesExpanded ? root.thumbGap : root.compactGap;
        let x = root.spacesRowX;
        for (let i = 0; i < n; i++) {
            const local = root.spaceLocals[i];
            const w = root.spacesExpanded ? root.thumbW : root.compactLabelW(root.spaceLabel(i, local, root.windowsOn(root.base + local)));
            if (lx >= x && lx <= x + w)
                return { "index": i, "localWs": local, "plus": false };
            x += w + gap;
        }
        if (root.canAddSpace && lx >= root.plusX - 8 && lx <= root.plusX + root.plusSize + 8)
            return { "index": n, "localWs": 0, "plus": true };
        return { "index": -1, "localWs": 0, "plus": false };
    }

    function hitAt(lx, ly) {
        const miss = {
            "kind": "bg",
            "index": -1,
            "localWs": 0,
            "toplevel": null,
            "close": false
        };
        const deskY = root.spacesExpanded ? 10 : 8;
        const hitH = root.spacesExpanded ? root.thumbH + 22 : 28;
        const n = root.spaceLocals.length;
        if (ly >= 0 && ly <= deskY + hitH) {
            const slot = root.spaceSlotAt(lx);
            if (slot.plus)
                return {
                    "kind": "add",
                    "index": slot.index,
                    "localWs": 0,
                    "toplevel": null,
                    "close": false
                };
            if (slot.localWs >= 1) {
                let sx = root.spacesRowX;
                const gap = root.spacesExpanded ? root.thumbGap : root.compactGap;
                for (let i = 0; i < slot.index; i++) {
                    const local = root.spaceLocals[i];
                    const w = root.spacesExpanded ? root.thumbW : root.compactLabelW(root.spaceLabel(i, local, root.windowsOn(root.base + local)));
                    sx += w + gap;
                }
                const close = root.spacesExpanded && n > 1 && lx >= sx + 2 && lx <= sx + 22 && ly >= deskY + 2 && ly <= deskY + 22;
                return {
                    "kind": close ? "spaceClose" : "space",
                    "index": slot.index,
                    "localWs": slot.localWs,
                    "toplevel": null,
                    "close": close
                };
            }
        }
        const rects = root.exposeRects;
        const wins = root.previewWins;
        for (let i = rects.length - 1; i >= 0; i--) {
            const r = rects[i];
            if (lx < r.x || lx > r.x + r.w || ly < r.y || ly > r.y + r.h)
                continue;
            const close = lx >= r.x + 4 && lx <= r.x + 26 && ly >= r.y + 4 && ly <= r.y + 26;
            return {
                "kind": close ? "winClose" : "window",
                "index": i,
                "localWs": root.previewLocal,
                "toplevel": wins[i],
                "close": close
            };
        }
        return miss;
    }

    Image {
        anchors.fill: parent
        source: Services.WallpaperService.current ? ("file://" + Services.WallpaperService.current) : ""
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
        scale: 1
        opacity: root.intro
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22 + root.intro * 0.3)
    }

    Item {
        id: spacesBar
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.spacesBarH
        y: 0
        opacity: 1
        clip: true

        Row {
            id: spacesRow
            x: root.spacesRowX
            anchors.top: parent.top
            anchors.topMargin: root.spacesExpanded ? 12 : 10
            spacing: root.spacesExpanded ? root.thumbGap : root.compactGap

            Behavior on x {
                enabled: !root.spacesExpanded
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: ListModel {
                    id: spaceModel
                }

                delegate: Item {
                    id: spaceCard
                    required property int index
                    required property int ws
                    readonly property int localWs: {
                        const _ = Core.Session.spaceRev;
                        const list = root.spaceLocals;
                        const id = list[spaceCard.index];
                        return Number(id || spaceCard.ws || 1);
                    }
                    readonly property int workspace: root.base + spaceCard.localWs
                    readonly property bool focused: root.previewLocal === spaceCard.localWs
                    readonly property bool dropTarget: Core.Session.overviewDrag && Core.Session.overviewDropMonitor === root.monitorName && !Core.Session.overviewDropPlus && Core.Session.overviewDropLocal === spaceCard.localWs && !Core.Session.overviewDropSwap
                    readonly property bool draggingThis: Core.Session.overviewDrag && Core.Session.overviewDragKind === "space" && Core.Session.overviewDragFromMonitor === root.monitorName && Core.Session.overviewDragFromLocal === spaceCard.localWs
                    readonly property bool hovered: !grab.dragging && grab.hoverIndex === spaceCard.index && (grab.hoverKind === "space" || grab.hoverKind === "spaceClose")
                    readonly property bool closeHovered: !grab.dragging && grab.hoverKind === "spaceClose" && grab.hoverIndex === spaceCard.index
                    readonly property var wins: root.windowsOn(spaceCard.workspace)

                    readonly property string caption: root.spaceLabel(spaceCard.index, spaceCard.localWs, spaceCard.wins)

                    width: root.spacesExpanded ? root.thumbW : root.compactLabelW(spaceCard.caption)
                    height: root.spacesExpanded ? root.thumbH + 22 : 22
                    opacity: {
                        if (spaceCard.draggingThis)
                            return 0.35;
                        if (root.spacesExpanded)
                            return 1;
                        return root.stripFade(root.spacesRowX + spaceCard.x, spaceCard.width);
                    }

                    Behavior on opacity {
                        enabled: !root.spacesExpanded
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    Tactile {
                        width: parent.width
                        height: root.spacesExpanded ? root.thumbH : parent.height
                        anchors.top: parent.top
                        radius: root.spacesExpanded ? 6 : 4
                        hovered: spaceCard.hovered
                        pressed: grab.pressed && !grab.dragging && grab.pressKind === "space" && grab.pressIndex === spaceCard.index
                        active: spaceCard.focused || spaceCard.dropTarget
                        restScale: spaceCard.dropTarget ? 1.06 : 1
                        hoverScale: root.spacesExpanded ? 1.04 : 1
                        pressScale: root.spacesExpanded ? 0.96 : 0.98
                        activeFill: "transparent"
                    }

                    Rectangle {
                        id: desk
                        width: root.thumbW
                        height: root.thumbH
                        anchors.top: parent.top
                        visible: root.spacesExpanded
                        radius: 6
                        color: Qt.rgba(0.08, 0.08, 0.1, 0.72)
                        border.width: (spaceCard.focused || spaceCard.dropTarget) ? 3 : 1
                        border.color: (spaceCard.focused || spaceCard.dropTarget) ? root.spaceActive : Qt.rgba(1, 1, 1, 0.22)
                        clip: true
                        antialiasing: true

                        Image {
                            anchors.fill: parent
                            source: Services.WallpaperService.current ? ("file://" + Services.WallpaperService.current) : ""
                            fillMode: Image.PreserveAspectCrop
                            opacity: 0.9
                            visible: status === Image.Ready
                        }

                        Repeater {
                            model: spaceCard.wins.length

                            delegate: Item {
                                required property int index
                                readonly property var modelData: spaceCard.wins[index]
                                readonly property var ipc: (modelData && modelData.lastIpcObject) ? modelData.lastIpcObject : {}
                                readonly property var at: root.localAt(ipc.at || [0, 0])
                                readonly property var size: ipc.size || [320, 240]
                                x: Math.max(0, Number(at[0]) * root.thumbScale)
                                y: Math.max(0, Number(at[1]) * root.thumbScale)
                                width: Math.max(8, Number(size[0]) * root.thumbScale)
                                height: Math.max(6, Number(size[1]) * root.thumbScale)

                                WindowPreview {
                                    id: thumbShot
                                    anchors.fill: parent
                                    toplevel: modelData
                                    live: false
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 2
                                    color: Qt.rgba(0.92, 0.93, 0.95, 0.88)
                                    visible: !thumbShot.ready
                                }

                                Image {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width * 0.7, 18)
                                    height: width
                                    asynchronous: true
                                    cache: true
                                    fillMode: Image.PreserveAspectFit
                                    source: Services.AppsService.iconPathForClass(String(ipc.class || ipc.initialClass || ""), String(modelData.title || ipc.title || ""))
                                    visible: status === Image.Ready
                                }
                            }
                        }
                    }

                    Text {
                        id: spaceCaption
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.spacesExpanded ? root.thumbH + 4 : Math.round((parent.height - implicitHeight) / 2)
                        width: parent.width
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        text: spaceCard.caption
                        color: spaceCard.focused ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.78)
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: root.spacesExpanded ? 11 : 14
                        font.weight: spaceCard.focused ? Font.DemiBold : Font.Medium
                    }

                    Rectangle {
                        id: spaceClose
                        z: 20
                        width: 14
                        height: 14
                        radius: 7
                        anchors.top: desk.top
                        anchors.left: desk.left
                        anchors.topMargin: 6
                        anchors.leftMargin: 6
                        visible: root.spacesExpanded && root.spaceLocals.length > 1
                        color: spaceCard.closeHovered ? "#FF5F57" : Qt.rgba(0.18, 0.18, 0.2, 0.92)
                        opacity: spaceCard.hovered && !Core.Session.overviewDrag ? 1 : 0
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, spaceCard.closeHovered ? 0.08 : 0.28)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: spaceCard.closeHovered ? "#4A0000" : "#FFFFFF"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        Item {
            id: addCard
            visible: root.canAddSpace
            width: root.plusSize
            height: root.spacesExpanded ? root.thumbH + 22 : 22
            x: root.plusX
            y: root.spacesExpanded ? 12 : 10
            z: 40

            Tactile {
                width: root.plusSize
                height: root.plusSize
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: root.spacesExpanded ? Math.max(0, (root.thumbH - root.plusSize) / 2) : 0
                radius: root.plusSize / 2
                hovered: !grab.dragging && grab.hoverKind === "add"
                pressed: grab.pressed && !grab.dragging && grab.pressKind === "add"
                active: Core.Session.overviewDrag && Core.Session.overviewDropPlus && Core.Session.overviewDropMonitor === root.monitorName
                restScale: Core.Session.overviewDrag && Core.Session.overviewDropPlus && Core.Session.overviewDropMonitor === root.monitorName ? 1.08 : 1
                hoverScale: 1.06
                pressScale: 0.94
                activeFill: "transparent"
            }

            Rectangle {
                id: addDesk
                width: root.plusSize
                height: root.plusSize
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: root.spacesExpanded ? Math.max(0, (root.thumbH - root.plusSize) / 2) : 0
                radius: root.plusSize / 2
                color: Qt.rgba(1, 1, 1, (!grab.dragging && grab.hoverKind === "add") ? 0.22 : 0.12)
                border.width: (Core.Session.overviewDrag && Core.Session.overviewDropPlus && Core.Session.overviewDropMonitor === root.monitorName) ? 2 : 1
                border.color: (Core.Session.overviewDrag && Core.Session.overviewDropPlus && Core.Session.overviewDropMonitor === root.monitorName) ? root.spaceActive : Qt.rgba(1, 1, 1, 0.34)
                antialiasing: true

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: "#FFFFFF"
                    opacity: 0.9
                    font.pixelSize: Math.round(addDesk.height * 0.55)
                    font.weight: Font.Light
                }
            }
        }
    }

    Repeater {
        model: root.previewWins.length

        delegate: Item {
            id: win
            required property int index
            readonly property var modelData: root.previewWins[win.index]
            readonly property var ipc: (win.modelData && win.modelData.lastIpcObject) ? win.modelData.lastIpcObject : {}
            readonly property var at: win.ipc.at || [0, 0]
            readonly property var size: win.ipc.size || [960, 540]
            readonly property var rect: root.exposeRects[win.index] || {
                "x": 0,
                "y": 0,
                "w": 240,
                "h": 150
            }
            readonly property string cls: String(win.ipc.class || win.ipc.initialClass || "")
            readonly property string winTitle: String(win.modelData.title || win.ipc.title || Services.AppsService.nameForClass(win.cls, win.cls))
            readonly property bool dropTarget: Core.Session.overviewDrag && Core.Session.overviewDropSwap && Core.Session.windowAddress(Core.Session.overviewDropSwap) === Core.Session.windowAddress(win.modelData)
            readonly property bool draggingThis: Core.Session.overviewDrag && Core.Session.overviewDragKind === "window" && Core.Session.windowAddress(Core.Session.overviewDragToplevel) !== "" && Core.Session.windowAddress(Core.Session.overviewDragToplevel) === Core.Session.windowAddress(win.modelData)
            readonly property bool hovered: !grab.dragging && grab.hoverIndex === win.index && (grab.hoverKind === "window" || grab.hoverKind === "winClose")
            readonly property bool closeHovered: !grab.dragging && grab.hoverKind === "winClose" && grab.hoverIndex === win.index

            x: win.rect.x
            y: win.rect.y
            width: win.rect.w
            height: win.rect.h
            z: win.draggingThis ? 80 : 10
            opacity: 1
            scale: win.dropTarget ? 1.04 : 1
            visible: !win.draggingThis

            Rectangle {
                id: shadow
                anchors.fill: chrome
                anchors.margins: -14
                radius: 28
                color: Qt.rgba(0, 0, 0, 0.42)
                opacity: 0.8
            }

            Rectangle {
                id: chrome
                anchors.fill: parent
                radius: 20
                color: Qt.rgba(0.16, 0.17, 0.2, 0.92)
                border.width: win.dropTarget ? 3 : 0
                border.color: win.dropTarget ? root.spaceActive : "transparent"
                clip: true
                antialiasing: true
                layer.enabled: true
                layer.smooth: true

                WindowPreview {
                    id: livePreview
                    anchors.fill: parent
                    toplevel: win.modelData
                    live: true
                }

                Image {
                    anchors.fill: parent
                    source: Services.WallpaperService.current ? ("file://" + Services.WallpaperService.current) : ""
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.22
                    visible: status === Image.Ready && !livePreview.ready
                }
            }

            Rectangle {
                id: closeBtn
                z: 12
                width: 14
                height: 14
                radius: 7
                anchors.top: chrome.top
                anchors.left: chrome.left
                anchors.topMargin: 8
                anchors.leftMargin: 8
                color: win.closeHovered ? "#FF5F57" : Qt.rgba(0.2, 0.2, 0.22, 0.88)
                opacity: win.hovered && !Core.Session.overviewDrag ? 1 : 0
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: win.closeHovered ? "#4A0000" : "#FFFFFF"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Item {
        id: ghost
        visible: (grab.dragging && grab.pressKind === "space") || (Core.Session.overviewDrag && root.pointerHere)
        z: 200
        width: 220
        height: 148
        x: (grab.dragging ? grab.dragX : (Core.Session.overviewDragX - root.monitorX)) - width / 2
        y: (grab.dragging ? grab.dragY : (Core.Session.overviewDragY - root.monitorY)) - height / 2
        opacity: 0.92
        scale: 0.92

        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: 28
            radius: 10
            color: Qt.rgba(0.16, 0.17, 0.2, 0.95)
            border.width: 1
            border.color: "#FFFFFF"
        }

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -10
            width: 48
            height: 48
            visible: Core.Session.overviewDragKind !== "space"
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            source: {
                const t = Core.Session.overviewDragToplevel;
                if (!t)
                    return "";
                return Services.AppsService.iconPathForWindow(t);
            }
        }

        Text {
            visible: Core.Session.overviewDragKind === "space"
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -8
            text: "Desktop " + root.labelFor(Core.Session.overviewDragFromLocal)
            color: "#FFFFFF"
            font.family: Core.Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: grab
        anchors.fill: parent
        z: 250
        enabled: Core.Session.overviewOpen
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton
        cursorShape: grab.dragging ? Qt.ClosedHandCursor : ((grab.hoverKind === "window" || grab.hoverKind === "space") ? Qt.OpenHandCursor : Qt.ArrowCursor)

        property string hoverKind: ""
        property int hoverIndex: -1
        property var hoverToplevel: null
        property int hoverLocal: 0
        property bool hoverClose: false
        property bool dragging: false
        property bool didDrag: false
        property real pressX: 0
        property real pressY: 0
        property string pressKind: ""
        property int pressIndex: -1
        property var pressToplevel: null
        property int pressLocal: 0
        property bool pressClose: false

        property real dragX: 0
        property real dragY: 0

        function applyHover(mouse) {
            const band = root.spacesExpanded ? root.spacesBarH + 8 : root.compactBarH + 6;
            if (grab.dragging || Core.Session.overviewDrag || mouse.y <= band)
                root.spacesExpanded = true;
            else
                root.spacesExpanded = false;
            const h = root.hitAt(mouse.x, mouse.y);
            grab.hoverKind = h.kind;
            grab.hoverIndex = h.index;
            grab.hoverToplevel = h.toplevel;
            grab.hoverLocal = h.localWs;
            grab.hoverClose = h.close;
            if (!grab.dragging && !Core.Session.overviewDrag && (h.kind === "space" || h.kind === "spaceClose") && h.localWs >= 1)
                root.previewLocal = h.localWs;
        }

        function globalFrom(mouse) {
            return [root.monitorX + mouse.x * root.monitorW / Math.max(1, root.width), root.monitorY + mouse.y * root.monitorH / Math.max(1, root.height)];
        }

        onPressed: function (mouse) {
            if (Core.Session.overviewDrag) {
                grab.dragging = true;
                grab.didDrag = true;
                grab.pressKind = "window";
                mouse.accepted = true;
                const g = grab.globalFrom(mouse);
                Core.Session.updateOverviewDrag(g[0], g[1]);
                root.publishDrop();
                return;
            }
            const h = root.hitAt(mouse.x, mouse.y);
            grab.dragging = false;
            grab.didDrag = false;
            grab.pressX = mouse.x;
            grab.pressY = mouse.y;
            grab.pressKind = h.kind;
            grab.pressIndex = h.index;
            grab.pressToplevel = h.toplevel;
            grab.pressLocal = h.localWs;
            grab.pressClose = h.close;
            mouse.accepted = true;
        }
        onPositionChanged: function (mouse) {
            if (!grab.pressed) {
                grab.applyHover(mouse);
                return;
            }
            grab.dragX = mouse.x;
            grab.dragY = mouse.y;
            if (!grab.dragging && !grab.pressClose && Math.hypot(mouse.x - grab.pressX, mouse.y - grab.pressY) > 6) {
                const g = grab.globalFrom(mouse);
                if (grab.pressKind === "window" && grab.pressToplevel) {
                    grab.dragging = true;
                    grab.didDrag = true;
                    Core.Session.beginOverviewDrag(grab.pressToplevel, root.monitorName, g[0], g[1]);
                } else if (grab.pressKind === "space" && grab.pressLocal >= 1) {
                    grab.dragging = true;
                    grab.didDrag = true;
                    Core.Session.beginOverviewSpaceDrag(root.monitorName, grab.pressLocal, g[0], g[1]);
                }
            }
            if (grab.dragging) {
                const g = grab.globalFrom(mouse);
                Core.Session.updateOverviewDrag(g[0], g[1]);
                if (grab.pressKind === "space") {
                    const slot = root.spaceSlotAt(mouse.x);
                    if (slot.plus)
                        Core.Session.setOverviewDrop(root.monitorName, 0, true, null);
                    else if (slot.localWs >= 1)
                        Core.Session.setOverviewDrop(root.monitorName, slot.localWs, false, null);
                } else {
                    root.publishDrop();
                }
                return;
            }
            grab.applyHover(mouse);
        }
        onReleased: function (mouse) {
            if (grab.didDrag && grab.pressKind === "space") {
                const x = mouse ? mouse.x : grab.dragX;
                const slot = root.spaceSlotAt(x);
                if (slot.plus)
                    Core.Session.reorderSpaceOnMonitor(root.monitorName, grab.pressLocal, 0, true);
                else if (slot.localWs >= 1 && slot.localWs !== grab.pressLocal)
                    Core.Session.reorderSpaceOnMonitor(root.monitorName, grab.pressLocal, slot.localWs, false);
                root.rebuildSpaces();
                Core.Session.clearOverviewDrag();
            } else if (grab.didDrag || Core.Session.overviewDrag) {
                if (mouse)
                    root.publishDrop();
                Core.Session.finishOverviewDrag();
            } else if (grab.pressKind === "winClose" && grab.pressToplevel)
                Core.Session.closeWindow(grab.pressToplevel);
            else if (grab.pressKind === "spaceClose")
                root.closeSpace(grab.pressLocal);
            else if (grab.pressKind === "window" && grab.pressToplevel)
                root.activateWindow(grab.pressToplevel);
            else if (grab.pressKind === "space")
                root.activateSpace(grab.pressLocal);
            else if (grab.pressKind === "add")
                root.addDesktop();
            else if (grab.pressKind === "bg")
                root.closeOverview();
            grab.dragging = false;
            grab.didDrag = false;
        }
        onCanceled: {
            grab.dragging = false;
        }
        onExited: {
            if (grab.dragging)
                return;
            if (!Core.Session.overviewDrag)
                root.spacesExpanded = false;
            grab.hoverKind = "";
            grab.hoverIndex = -1;
            grab.hoverToplevel = null;
            grab.hoverLocal = 0;
            grab.hoverClose = false;
        }
    }

    Item {
        width: 0
        height: 0
        focus: Core.Session.overviewOpen
        Keys.onEscapePressed: root.closeOverview()
        Keys.onReturnPressed: root.closeOverview()
    }
}
