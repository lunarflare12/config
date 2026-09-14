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
    property real intro: 0
    property bool settle: false

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
        const seen = {};
        seen[Core.Session.localId(root.activeGlobal)] = true;
        seen[root.previewLocal] = true;
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const id = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (id > root.base && id <= root.base + root.count)
                seen[id - root.base] = true;
        }
        const out = [];
        for (let local = 1; local <= root.count; local++) {
            if (seen[local])
                out.push(local);
        }
        return out;
    }
    readonly property bool canAddSpace: root.spaceLocals.length < root.count
    readonly property var previewWins: {
        const _ = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0;
        return root.windowsOn(root.base + root.previewLocal);
    }
    readonly property real spacesBarH: Math.round(root.monitorH * 0.118) + 28
    readonly property real thumbW: {
        const n = root.spaceLocals.length + (root.canAddSpace ? 1 : 0);
        const avail = Math.min(root.width - 80, 1180);
        return Math.min(158, Math.max(88, Math.floor((avail - Math.max(0, n - 1) * 12) / Math.max(1, n))));
    }
    readonly property real thumbH: Math.round(root.thumbW * root.monitorH / Math.max(1, root.monitorW))
    readonly property real thumbScale: root.thumbW / Math.max(1, root.monitorW)
    readonly property var exposeRects: root.computeExpose(root.previewWins)
    readonly property bool pointerHere: {
        if (!Core.Session.overviewDrag)
            return false;
        let gx = Core.Session.overviewDragX;
        const gy = Core.Session.overviewDragY;
        if (Core.Session.overviewDragFromMonitor === root.monitorName) {
            if (gx <= root.monitorX + 16 && root.monitorIndexLeft())
                gx = root.monitorX - 8;
            else if (gx >= root.monitorX + root.monitorW - 16 && root.monitorIndexRight())
                gx = root.monitorX + root.monitorW + 8;
        }
        return gx >= root.monitorX && gx < root.monitorX + root.monitorW && gy >= root.monitorY && gy < root.monitorY + root.monitorH;
    }

    onPointerHereChanged: {
        if (root.pointerHere)
            root.publishDrop();
    }

    Connections {
        target: Core.Session
        function onOverviewOpenChanged() {
            if (Core.Session.overviewOpen) {
                Core.PopupManager.close();
                root.previewLocal = Core.Session.localId(root.activeGlobal);
                root.settle = false;
                introAnim.stop();
                root.intro = 0;
                introAnim.to = 1;
                introAnim.start();
                settleTimer.restart();
            } else {
                root.settle = false;
                introAnim.stop();
                introAnim.to = 0;
                introAnim.start();
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

    NumberAnimation {
        id: introAnim
        target: root
        property: "intro"
        duration: 520
        easing.type: Easing.OutCubic
        to: 1
    }

    Timer {
        id: settleTimer
        interval: 16
        repeat: false
        onTriggered: root.settle = true
    }

    WlrLayershell.namespace: "aurora-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Core.Session.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function windowsOn(globalId) {
        const out = [];
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            if (Core.Session.overviewDrag && Core.Session.overviewDragToplevel && Core.Session.windowAddress(t) === Core.Session.windowAddress(Core.Session.overviewDragToplevel))
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
        const stageW = Math.max(1, root.width - 96);
        const stageH = Math.max(1, root.height - root.spacesBarH - 48);
        const originX = 48;
        const originY = root.spacesBarH + 8;
        if (n === 0)
            return [];
        const cols = n === 1 ? 1 : n === 2 ? 2 : n <= 4 ? 2 : n <= 6 ? 3 : 4;
        const rows = Math.ceil(n / cols);
        const gap = 36;
        const cellW = (stageW - gap * (cols + 1)) / cols;
        const cellH = (stageH - gap * (rows + 1)) / rows;
        const out = [];
        for (let i = 0; i < n; i++) {
            const ipc = wins[i].lastIpcObject || {};
            const size = ipc.size || [960, 540];
            const rw = Math.max(1, Number(size[0]));
            const rh = Math.max(1, Number(size[1]));
            const maxW = cellW * 0.92;
            const maxH = cellH * 0.78;
            const s = Math.min(maxW / rw, maxH / rh);
            const w = Math.max(160, rw * s);
            const h = Math.max(100, rh * s);
            const col = i % cols;
            const row = Math.floor(i / cols);
            const cx = originX + gap + col * (cellW + gap) + cellW / 2;
            const cy = originY + gap + row * (cellH + gap) + cellH / 2 - 10;
            out.push({
                x: cx - w / 2,
                y: cy - h / 2,
                w: w,
                h: h
            });
        }
        return out;
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

    function labelFor(localWs) {
        return localWs === 10 ? "0" : String(localWs);
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
        let gx = Core.Session.overviewDragX;
        const gy = Core.Session.overviewDragY;
        if (Core.Session.overviewDragFromMonitor === root.monitorName) {
            if (gx <= root.monitorX + 16 && root.monitorIndexLeft())
                gx = root.monitorX - 8;
            else if (gx >= root.monitorX + root.monitorW - 16 && root.monitorIndexRight())
                gx = root.monitorX + root.monitorW + 8;
        }
        if (gx < root.monitorX || gx >= root.monitorX + root.monitorW)
            return;
        const lx = gx - root.monitorX;
        const ly = gy - root.monitorY;
        if (ly <= root.spacesBarH) {
            const n = root.spaceLocals.length + (root.canAddSpace ? 1 : 0);
            const total = n * root.thumbW + Math.max(0, n - 1) * 12;
            const start = (root.width - total) / 2;
            const idx = Math.floor((lx - start) / (root.thumbW + 12));
            if (idx >= 0 && idx < root.spaceLocals.length)
                Core.Session.setOverviewDrop(root.monitorName, root.spaceLocals[idx], false, null);
            else if (root.canAddSpace && idx === root.spaceLocals.length)
                Core.Session.setOverviewDrop(root.monitorName, 0, true, null);
            else
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

    Image {
        anchors.fill: parent
        source: Services.WallpaperService.current ? ("file://" + Services.WallpaperService.current) : ""
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
        scale: 1 + root.intro * 0.045
        opacity: root.intro
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18 + root.intro * 0.28)

        MouseArea {
            anchors.fill: parent
            enabled: Core.Session.overviewOpen && !Core.Session.overviewDrag
            onClicked: root.closeOverview()
        }
    }

    Item {
        id: spacesBar
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.spacesBarH
        y: -root.spacesBarH * (1 - root.intro)
        opacity: root.intro

        Row {
            id: spacesRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 12

            Repeater {
                model: root.spaceLocals.length

                delegate: Item {
                    id: spaceCard
                    required property int index
                    readonly property int localWs: root.spaceLocals[spaceCard.index]
                    readonly property int workspace: root.base + spaceCard.localWs
                    readonly property bool focused: root.previewLocal === spaceCard.localWs
                    readonly property bool dropTarget: Core.Session.overviewDrag && Core.Session.overviewDropMonitor === root.monitorName && !Core.Session.overviewDropPlus && Core.Session.overviewDropLocal === spaceCard.localWs && !Core.Session.overviewDropSwap
                    readonly property var wins: root.windowsOn(spaceCard.workspace)

                    width: root.thumbW
                    height: root.thumbH + 22

                    Tactile {
                        anchors.fill: parent
                        radius: 8
                        hovered: spaceMouse.containsMouse
                        pressed: spaceMouse.pressed
                        active: spaceCard.focused || spaceCard.dropTarget
                        restScale: spaceCard.dropTarget ? 1.06 : 1
                        hoverScale: 1.04
                        pressScale: 0.96
                        activeFill: "transparent"
                    }

                    Rectangle {
                        id: desk
                        width: root.thumbW
                        height: root.thumbH
                        anchors.top: parent.top
                        radius: 8
                        color: Qt.rgba(0.08, 0.08, 0.1, 0.72)
                        border.width: spaceCard.dropTarget ? 3 : (spaceCard.focused ? 2 : 1)
                        border.color: spaceCard.dropTarget ? "#FFFFFF" : (spaceCard.focused ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.22))
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
                                readonly property var at: ipc.at || [0, 0]
                                readonly property var size: ipc.size || [320, 240]
                                x: Math.max(0, (Number(at[0]) - root.monitorX) * root.thumbScale)
                                y: Math.max(0, (Number(at[1]) - root.monitorY) * root.thumbScale)
                                width: Math.max(8, Number(size[0]) * root.thumbScale)
                                height: Math.max(6, Number(size[1]) * root.thumbScale)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 2
                                    color: Qt.rgba(0.92, 0.93, 0.95, 0.88)
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
                        anchors.top: desk.bottom
                        anchors.topMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Desktop " + root.labelFor(spaceCard.localWs)
                        color: spaceCard.focused ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.72)
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: spaceCard.focused ? Font.DemiBold : Font.Medium
                    }

                    MouseArea {
                        id: spaceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !Core.Session.overviewDrag
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.previewLocal = spaceCard.localWs
                        onClicked: root.activateSpace(spaceCard.localWs)
                    }
                }
            }

            Item {
                id: addCard
                visible: root.canAddSpace
                width: root.thumbW
                height: root.thumbH + 22

                Tactile {
                    anchors.fill: parent
                    radius: 8
                    hovered: addMouse.containsMouse
                    pressed: addMouse.pressed
                    active: Core.Session.overviewDrag && Core.Session.overviewDropPlus && Core.Session.overviewDropMonitor === root.monitorName
                    restScale: Core.Session.overviewDrag && Core.Session.overviewDropPlus && Core.Session.overviewDropMonitor === root.monitorName ? 1.06 : 1
                    hoverScale: 1.04
                    pressScale: 0.96
                    activeFill: "transparent"
                }

                Rectangle {
                    id: addDesk
                    width: root.thumbW
                    height: root.thumbH
                    anchors.top: parent.top
                    radius: 8
                    color: Qt.rgba(1, 1, 1, addMouse.containsMouse ? 0.14 : 0.07)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.28)
                    antialiasing: true

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: "#FFFFFF"
                        opacity: 0.85
                        font.pixelSize: Math.round(addDesk.height * 0.32)
                        font.weight: Font.Light
                    }
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !Core.Session.overviewDrag
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addDesktop()
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

            x: root.settle ? win.rect.x : Math.max(0, Number(win.at[0]) - root.monitorX)
            y: root.settle ? win.rect.y : Math.max(0, Number(win.at[1]) - root.monitorY)
            width: root.settle ? win.rect.w : Math.max(80, Number(win.size[0]))
            height: (root.settle ? win.rect.h : Math.max(50, Number(win.size[1]))) + 44
            z: winMouse.dragging ? 80 : 10
            opacity: root.intro
            scale: win.dropTarget ? 1.04 : 1

            Behavior on x {
                enabled: root.settle
                NumberAnimation {
                    duration: 480
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: root.settle
                NumberAnimation {
                    duration: 480
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                enabled: root.settle
                NumberAnimation {
                    duration: 480
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: root.settle
                NumberAnimation {
                    duration: 480
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: shadow
                anchors.fill: chrome
                anchors.margins: -10
                radius: 18
                color: Qt.rgba(0, 0, 0, 0.35)
                opacity: 0.7
            }

            Rectangle {
                id: chrome
                width: parent.width
                height: parent.height - 44
                radius: Core.Theme.radiusRow
                color: Qt.rgba(0.16, 0.17, 0.2, 0.92)
                border.width: win.dropTarget ? 3 : 1
                border.color: win.dropTarget ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.16)
                clip: true
                antialiasing: true

                Tactile {
                    anchors.fill: parent
                    radius: parent.radius
                    hovered: winMouse.containsMouse
                    pressed: winMouse.pressed
                    feelTarget: chrome
                    hoverScale: 1.03
                    pressScale: 0.96
                    activeFill: "transparent"
                }

                Image {
                    anchors.fill: parent
                    source: Services.WallpaperService.current ? ("file://" + Services.WallpaperService.current) : ""
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.22
                    visible: status === Image.Ready
                }
            }

            Image {
                id: appIcon
                z: 4
                width: Math.round(Math.min(58, chrome.height * 0.28))
                height: width
                anchors.horizontalCenter: chrome.horizontalCenter
                anchors.verticalCenter: chrome.bottom
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectFit
                source: Services.AppsService.iconPathForClass(win.cls, win.winTitle)
                visible: status === Image.Ready
            }

            Text {
                visible: appIcon.status !== Image.Ready
                z: 4
                anchors.horizontalCenter: chrome.horizontalCenter
                anchors.verticalCenter: chrome.bottom
                text: Core.Icons.forApp(win.cls || win.winTitle)
                font.family: Core.Theme.iconFont
                font.pixelSize: 28
                color: "#FFFFFF"
            }

            Text {
                anchors.top: chrome.bottom
                anchors.topMargin: 22
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                text: win.winTitle
                color: "#FFFFFF"
                font.family: Core.Theme.fontFamily
                font.pixelSize: 12
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.55)
            }

            MouseArea {
                id: winMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.OpenHandCursor
                property bool dragging: false
                property real pressX: 0
                property real pressY: 0

                onPressed: function (mouse) {
                    winMouse.dragging = false;
                    winMouse.pressX = mouse.x;
                    winMouse.pressY = mouse.y;
                }
                onPositionChanged: function (mouse) {
                    if (!winMouse.pressed)
                        return;
                    if (!winMouse.dragging && Math.hypot(mouse.x - winMouse.pressX, mouse.y - winMouse.pressY) > 8) {
                        winMouse.dragging = true;
                        const p = winMouse.mapToItem(root, mouse.x, mouse.y);
                        Core.Session.beginOverviewDrag(win.modelData, root.monitorName, root.monitorX + p.x, root.monitorY + p.y);
                    }
                    if (winMouse.dragging) {
                        const p = winMouse.mapToItem(root, mouse.x, mouse.y);
                        let gx = root.monitorX + p.x;
                        const gy = root.monitorY + p.y;
                        if (p.x < 16 && root.monitorIndexLeft())
                            gx = root.monitorX - 24;
                        else if (p.x > root.width - 16 && root.monitorIndexRight())
                            gx = root.monitorX + root.monitorW + 24;
                        Core.Session.updateOverviewDrag(gx, gy);
                    }
                }
                onReleased: {
                    if (winMouse.dragging)
                        Core.Session.finishOverviewDrag();
                    winMouse.dragging = false;
                }
                onClicked: {
                    if (!winMouse.dragging)
                        root.activateWindow(win.modelData);
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
                color: closeMouse.containsMouse ? "#FF5F57" : Qt.rgba(0.2, 0.2, 0.22, 0.88)
                opacity: (winMouse.containsMouse || closeMouse.containsMouse) && !winMouse.dragging && !Core.Session.overviewDrag ? 1 : 0
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
                    color: closeMouse.containsMouse ? "#4A0000" : "#FFFFFF"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function (mouse) {
                        mouse.accepted = true;
                        Core.Session.closeWindow(win.modelData);
                    }
                }
            }
        }
    }

    Item {
        id: ghost
        visible: Core.Session.overviewDrag && root.pointerHere
        z: 200
        width: 220
        height: 148
        x: Core.Session.overviewDragX - root.monitorX - width / 2
        y: Core.Session.overviewDragY - root.monitorY - height / 2
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
    }

    Item {
        anchors.fill: parent
        focus: Core.Session.overviewOpen
        Keys.onEscapePressed: root.closeOverview()
        Keys.onReturnPressed: root.closeOverview()
    }
}
