import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property var grid: Services.DesktopGrid
    readonly property var svc: Services.DesktopService
    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property bool gameFullscreen: Core.Session.gameFullscreenOnScreen(root.screen)
    readonly property bool shown: !root.gameFullscreen && !Core.Session.overviewOpen
    readonly property bool desktopHost: Core.Session.isDesktopMonitor(root.monitorName)

    // Stagger widget trees across frames; other monitors never instantiate them.
    property int widgetGate: 0

    onDesktopHostChanged: {
        if (!root.desktopHost)
            root.widgetGate = 0;
    }

    readonly property int cellW: root.grid.cellWFor(width)
    readonly property int cellH: root.grid.cellHFor(height)
    readonly property int cols: root.grid.colsFor(width)
    readonly property int rows: root.grid.rowsFor(height)

    function posX(col) {
        return root.grid.posX(col, root.cellW);
    }

    function posY(row) {
        return root.grid.posY(row, root.cellH);
    }

    function colAt(x) {
        return root.grid.colAt(x, root.cellW);
    }

    function rowAt(y) {
        return root.grid.rowAt(y, root.cellH);
    }

    property bool boxing: false
    property real boxX: 0
    property real boxY: 0
    property real boxX2: 0
    property real boxY2: 0
    property bool menuOpen: false
    property bool menuOnIcon: false
    property real menuX: 0
    property real menuY: 0
    readonly property bool editing: Core.Session.desktopEdit
    property bool arranging: false
    property var occupied: ({})

    function place(id, col, row, spanW, spanH) {
        if (!id)
            return;
        const next = Object.assign({}, root.occupied);
        next[id] = {
            col: col,
            row: row,
            w: Math.max(1, spanW || 1),
            h: Math.max(1, spanH || 1)
        };
        root.occupied = next;
    }

    function unplace(id) {
        if (!id || !root.occupied[id])
            return;
        const next = Object.assign({}, root.occupied);
        delete next[id];
        root.occupied = next;
    }

    function overlaps(aCol, aRow, aW, aH, bCol, bRow, bW, bH) {
        return aCol < bCol + bW && aCol + aW > bCol && aRow < bRow + bH && aRow + aH > bRow;
    }

    function isFree(col, row, spanW, spanH, exceptId) {
        const keys = Object.keys(root.occupied);
        for (let i = 0; i < keys.length; i++) {
            const id = keys[i];
            if (id === exceptId)
                continue;
            const cell = root.occupied[id];
            if (root.overlaps(col, row, spanW, spanH, cell.col, cell.row, cell.w, cell.h))
                return false;
        }
        return true;
    }

    function snapTo(col, row, spanW, spanH, exceptId) {
        const sw = Math.max(1, spanW || 1);
        const sh = Math.max(1, spanH || 1);
        col = root.grid.clampCol(col, sw, root.cols);
        row = root.grid.clampRow(row, sh, root.rows);
        if (root.isFree(col, row, sw, sh, exceptId))
            return {
                col: col,
                row: row
            };

        const maxC = Math.max(0, root.cols - sw);
        const maxR = Math.max(0, root.rows - sh);
        const limit = Math.max(root.cols, root.rows);
        for (let d = 1; d <= limit; d++) {
            for (let dc = -d; dc <= d; dc++) {
                for (let dr = -d; dr <= d; dr++) {
                    if (Math.abs(dc) !== d && Math.abs(dr) !== d)
                        continue;
                    const c = col + dc;
                    const r = row + dr;
                    if (c < 0 || r < 0 || c > maxC || r > maxR)
                        continue;
                    if (root.isFree(c, r, sw, sh, exceptId))
                        return {
                            col: c,
                            row: r
                        };
                }
            }
        }

        return {
            col: col,
            row: row
        };
    }

    function cellTaken(col, row) {
        const keys = Object.keys(root.occupied);
        for (let i = 0; i < keys.length; i++) {
            const cell = root.occupied[keys[i]];
            if (!cell)
                continue;
            if (col >= cell.col && col < cell.col + cell.w && row >= cell.row && row < cell.row + cell.h)
                return true;
        }
        return false;
    }

    function firstFree(exceptId) {
        for (let c = 0; c < root.cols; c++) {
            for (let r = 0; r < root.rows; r++) {
                if (root.isFree(c, r, 1, 1, exceptId))
                    return {
                        col: c,
                        row: r
                    };
            }
        }
        return {
            col: 0,
            row: 0
        };
    }

    function iconId(path) {
        return "icon:" + String(path || "");
    }

    function intersectsBox(x, y) {
        const rx = Math.min(root.boxX, root.boxX2);
        const ry = Math.min(root.boxY, root.boxY2);
        const rw = Math.abs(root.boxX2 - root.boxX);
        const rh = Math.abs(root.boxY2 - root.boxY);
        return x < rx + rw && x + root.cellW > rx && y < ry + rh && y + root.cellH > ry;
    }

    function applyBoxSelect() {
        const paths = [];
        const items = root.svc.items;
        for (let i = 0; i < items.length; i++) {
            const id = root.iconId(items[i].path);
            const cell = root.occupied[id];
            if (!cell)
                continue;
            if (root.intersectsBox(root.posX(cell.col), root.posY(cell.row)))
                paths.push(items[i].path);
        }
        root.svc.selectPaths(paths);
    }

    function closeMenu() {
        root.menuOpen = false;
        Core.PopupManager.contextMenuOpen = false;
    }

    function openEmptyMenu(x, y) {
        root.menuOnIcon = false;
        root.menuX = x;
        root.menuY = y;
        root.menuOpen = true;
        Core.PopupManager.contextMenuOpen = true;
        stage.forceActiveFocus();
    }

    function openIconMenu(x, y, path) {
        if (!root.svc.isSelected(path))
            root.svc.selectOnly(path);
        root.menuOnIcon = true;
        root.menuX = x;
        root.menuY = y;
        root.menuOpen = true;
        Core.PopupManager.contextMenuOpen = true;
        stage.forceActiveFocus();
    }

    function handleIconClick(path, modifiers) {
        root.closeMenu();
        if (root.editing)
            return;
        if (modifiers & Qt.ControlModifier) {
            root.svc.toggleSelect(path);
            return;
        }
        root.svc.selectOnly(path);
        root.svc.open(path);
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: root.shown

    WlrLayershell.namespace: "aurora-desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: {
        if (!root.shown)
            return WlrKeyboardFocus.None;
        if (root.menuOpen)
            return WlrKeyboardFocus.Exclusive;
        if (Core.Session.desktopEdit)
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.None;
    }

    mask: Region {
        item: passBar
    }

    Item {
        id: passBar
        anchors.fill: parent
        anchors.topMargin: Core.Theme.barHeight
    }

    Item {
        id: stage
        anchors.fill: parent
        focus: root.shown

        Connections {
            target: Core.Session
            function onDesktopEditChanged() {
                if (Core.Session.desktopEdit)
                    stage.forceActiveFocus();
            }
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                if (root.menuOpen) {
                    root.closeMenu();
                    event.accepted = true;
                    return;
                }
                root.svc.clearSelection();
                if (Core.Session.desktopEdit)
                    Core.Session.desktopEdit = false;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                root.svc.selectAll();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                root.svc.trashSelected();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_F2 && root.svc.selected.length === 1) {
                root.svc.beginRename(root.svc.selected[0]);
                event.accepted = true;
                return;
            }
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.svc.selected.length === 1) {
                root.svc.open(root.svc.selected[0]);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Space && !event.modifiers && !root.svc.renaming && root.svc.selected.length) {
                Core.Session.togglePreview(root.svc.selected);
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            z: 0

            onPressed: function (mouse) {
                if (Core.Session.sattyOpen) {
                    Core.Session.dismissScreenshot();
                    return;
                }
                stage.forceActiveFocus();
                root.closeMenu();
                if (mouse.button === Qt.RightButton) {
                    root.svc.clearSelection();
                    root.openEmptyMenu(mouse.x, mouse.y);
                    return;
                }
                root.boxing = true;
                root.boxX = mouse.x;
                root.boxY = mouse.y;
                root.boxX2 = mouse.x;
                root.boxY2 = mouse.y;
                if (!(mouse.modifiers & Qt.ControlModifier))
                    root.svc.clearSelection();
            }

            onPositionChanged: function (mouse) {
                if (!root.boxing)
                    return;
                root.boxX2 = mouse.x;
                root.boxY2 = mouse.y;
                root.applyBoxSelect();
            }

            onReleased: function (mouse) {
                if (mouse.button !== Qt.LeftButton)
                    return;
                const dragged = Math.hypot(root.boxX2 - root.boxX, root.boxY2 - root.boxY) > 8;
                root.boxing = false;
                if (!dragged)
                    Core.Session.dismissScreenshot();
                if (root.editing && !dragged) {
                    root.svc.clearSelection();
                    Core.Session.desktopEdit = false;
                }
            }
        }

        Repeater {
            model: (root.editing && root.desktopHost) ? root.cols * root.rows : 0

            Rectangle {
                required property int index
                readonly property int col: index % root.cols
                readonly property int row: Math.floor(index / root.cols)

                x: root.posX(col) + 3
                y: root.posY(row) + 3
                width: root.cellW - 6
                height: root.cellH - 6
                z: 1
                radius: 12
                visible: !root.cellTaken(col, row)
                color: Qt.alpha(Core.Theme.foreground, 0.12)
                border.width: 1
                border.color: Qt.alpha(Core.Theme.foreground, root.arranging ? 0.55 : 0.38)
                enabled: false
            }
        }

        Timer {
            interval: 16
            repeat: true
            running: root.desktopHost && root.widgetGate < 4
            onTriggered: root.widgetGate += 1
        }

        Component {
            id: clockComp
            DesktopClock {
                host: root
                modelData: root.modelData
                z: 6
            }
        }

        Component {
            id: metricsComp
            DesktopMetrics {
                host: root
                modelData: root.modelData
                z: 6
            }
        }

        Component {
            id: labsComp
            DesktopLabs {
                host: root
                modelData: root.modelData
                z: 6
            }
        }

        Component {
            id: nowPlayingComp
            DesktopNowPlaying {
                host: root
                modelData: root.modelData
                z: 6
            }
        }

        Loader {
            anchors.fill: parent
            active: root.widgetGate >= 1
            asynchronous: true
            sourceComponent: clockComp
        }

        Loader {
            anchors.fill: parent
            active: root.widgetGate >= 2
            asynchronous: true
            sourceComponent: metricsComp
        }

        Loader {
            anchors.fill: parent
            active: root.widgetGate >= 3
            asynchronous: true
            sourceComponent: labsComp
        }

        Loader {
            anchors.fill: parent
            active: root.widgetGate >= 4
            asynchronous: true
            sourceComponent: nowPlayingComp
        }

        Repeater {
            model: root.desktopHost ? root.svc.items : []

            Item {
                id: cell

                required property var modelData
                required property int index

                readonly property string slotId: root.iconId(cell.modelData.path)
                readonly property bool selected: root.svc.isSelected(cell.modelData.path)
                readonly property bool renaming: root.svc.renaming === cell.modelData.path

                property int col: 0
                property int row: 0
                property bool placed: false
                property bool dragging: false
                property bool moved: false
                property real dragX: 0
                property real dragY: 0

                width: root.cellW
                height: root.cellH
                x: cell.dragging ? cell.dragX : root.posX(cell.col)
                y: cell.dragging ? cell.dragY : root.posY(cell.row)
                z: cell.dragging ? 30 : 4

                function layout() {
                    if (root.width < 200 || root.cols < 4 || !root.monitorName || cell.dragging)
                        return;

                    const saved = Services.DesktopWidgets.get(root.monitorName, cell.slotId);
                    if (saved) {
                        cell.col = root.grid.clampCol(saved.col, 1, root.cols);
                        cell.row = root.grid.clampRow(saved.row, 1, root.rows);
                    } else {
                        const snap = root.firstFree(cell.slotId);
                        cell.col = snap.col;
                        cell.row = snap.row;
                        Services.DesktopWidgets.set(root.monitorName, cell.slotId, cell.col, cell.row);
                    }
                    cell.placed = true;
                    root.place(cell.slotId, cell.col, cell.row, 1, 1);
                }

                Timer {
                    interval: 80
                    running: root.cols >= 4
                    repeat: false
                    onTriggered: cell.layout()
                }
                Component.onDestruction: root.unplace(cell.slotId)

                Connections {
                    target: Core.Session
                    function onDesktopEditChanged() {
                        if (Core.Session.desktopEdit || !cell.dragging)
                            return;
                        const snap = root.snapTo(root.colAt(cell.dragX), root.rowAt(cell.dragY), 1, 1, cell.slotId);
                        cell.col = snap.col;
                        cell.row = snap.row;
                        cell.dragging = false;
                        root.arranging = false;
                        root.place(cell.slotId, cell.col, cell.row, 1, 1);
                        Services.DesktopWidgets.set(root.monitorName, cell.slotId, cell.col, cell.row);
                    }
                }

                Tactile {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    hovered: iconMouse.containsMouse
                    pressed: iconMouse.pressed
                    active: cell.selected
                    hoverScale: 1.08
                    pressScale: 0.9
                    activeFill: Qt.alpha(Core.Theme.accent, 0.42)
                }

                Image {
                    id: glyph
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    width: 52
                    height: 52
                    asynchronous: true
                    cache: true
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    source: root.svc.iconSource(cell.modelData)
                }

                Text {
                    visible: glyph.status !== Image.Ready
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 16
                    width: 44
                    height: 44
                    text: cell.modelData.isDir ? "📁" : "📄"
                    font.pixelSize: 36
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Core.Theme.emojiFont
                    renderType: Text.NativeRendering
                }

                Text {
                    visible: !cell.renaming
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    height: 26
                    text: root.svc.displayName(cell.modelData)
                    color: Core.Theme.foreground
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                TextInput {
                    id: renameInput
                    visible: cell.renaming
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    height: 26
                    text: root.svc.displayName(cell.modelData)
                    color: Core.Theme.foreground
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: TextInput.WrapAnywhere
                    selectByMouse: true
                    onVisibleChanged: {
                        if (visible) {
                            forceActiveFocus();
                            selectAll();
                        }
                    }
                    onAccepted: root.svc.rename(cell.modelData.path, text)
                    Keys.onEscapePressed: root.svc.renaming = ""
                    onActiveFocusChanged: {
                        if (!activeFocus && cell.renaming)
                            root.svc.rename(cell.modelData.path, text);
                    }
                }

                MouseArea {
                    id: iconMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    preventStealing: true
                    hoverEnabled: true
                    cursorShape: root.editing ? (cell.dragging ? Qt.SizeAllCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor

                    property real grabX: 0
                    property real grabY: 0

                    onPressed: function (mouse) {
                        mouse.accepted = true;
                        stage.forceActiveFocus();
                        if (mouse.button === Qt.RightButton) {
                            root.openIconMenu(cell.x + mouse.x, cell.y + mouse.y, cell.modelData.path);
                            return;
                        }
                        grabX = mouse.x;
                        grabY = mouse.y;
                        cell.moved = false;
                        cell.dragX = cell.x;
                        cell.dragY = cell.y;
                    }

                    onPositionChanged: function (mouse) {
                        if (!(pressed && mouse.buttons & Qt.LeftButton) || !root.editing)
                            return;
                        const dx = mouse.x - grabX;
                        const dy = mouse.y - grabY;
                        if (!cell.dragging && Math.abs(dx) + Math.abs(dy) < 6)
                            return;
                        if (!cell.dragging) {
                            cell.dragging = true;
                            root.arranging = true;
                        }
                        cell.moved = true;
                        cell.dragX = Math.round(cell.dragX + dx);
                        cell.dragY = Math.round(cell.dragY + dy);
                    }

                    onReleased: function (mouse) {
                        if (mouse.button !== Qt.LeftButton)
                            return;
                        if (cell.dragging) {
                            const snap = root.snapTo(root.colAt(cell.dragX), root.rowAt(cell.dragY), 1, 1, cell.slotId);
                            cell.col = snap.col;
                            cell.row = snap.row;
                            cell.dragging = false;
                            root.arranging = false;
                            root.place(cell.slotId, cell.col, cell.row, 1, 1);
                            Services.DesktopWidgets.set(root.monitorName, cell.slotId, cell.col, cell.row);
                            return;
                        }
                        root.handleIconClick(cell.modelData.path, mouse.modifiers);
                    }
                }
            }
        }

        Rectangle {
            visible: root.boxing
            x: Math.min(root.boxX, root.boxX2)
            y: Math.min(root.boxY, root.boxY2)
            width: Math.abs(root.boxX2 - root.boxX)
            height: Math.abs(root.boxY2 - root.boxY)
            z: 20
            color: Qt.alpha(Core.Theme.accent, 0.18)
            border.width: 1
            border.color: Core.Theme.accent
        }

        Rectangle {
            id: menuBox
            visible: root.menuOpen
            width: 188
            height: menuCol.implicitHeight + 10
            x: Math.max(8, Math.min(stage.width - width - 8, root.menuX))
            y: Math.max(8, Math.min(stage.height - height - 8, root.menuY))
            z: 50
            radius: Core.Theme.radiusMenu
            color: "transparent"
            border.width: Core.Theme.borderWidth
            border.color: Core.Theme.borderActive
            antialiasing: true

            Glass {
                anchors.fill: parent
                radius: parent.radius
                strength: 1.0
            }

            Column {
                id: menuCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5
                spacing: 1

                Repeater {
                    model: root.menuOnIcon ? [
                        {
                            "label": "Open",
                            "icon": Core.Icons.folder
                        },
                        {
                            "label": "Rename",
                            "icon": Core.Icons.file
                        },
                        {
                            "sep": true
                        },
                        {
                            "label": "Move to Trash",
                            "icon": Core.Icons.power,
                            "danger": true
                        }
                    ] : [
                        {
                            "label": "New Folder",
                            "icon": Core.Icons.folderPlus
                        },
                        {
                            "label": "New File",
                            "icon": Core.Icons.filePlus
                        },
                        {
                            "sep": true
                        },
                        {
                            "label": "Open Desktop",
                            "icon": Core.Icons.folder
                        }
                    ]

                    Loader {
                        id: entry
                        required property var modelData
                        width: menuCol.width
                        sourceComponent: entry.modelData.sep ? sepComp : rowComp

                        Component {
                            id: sepComp
                            Item {
                                height: 7
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 12
                                    height: 1
                                    color: Core.Theme.separator
                                }
                            }
                        }

                        Component {
                            id: rowComp
                            Rectangle {
                                height: 30
                                radius: Core.Theme.radiusRow
                                color: "transparent"

                                Tactile {
                                    anchors.fill: parent
                                    radius: Core.Theme.radiusRow
                                    hovered: rowMouse.containsMouse
                                    pressed: rowMouse.pressed
                                    hoverScale: 1.03
                                    pressScale: 0.94
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 9

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        text: entry.modelData.icon || ""
                                        font.family: Core.Theme.iconFont
                                        font.pixelSize: Core.Theme.iconSizeSmall
                                        color: entry.modelData.danger ? Core.Theme.danger : Core.Theme.foregroundMuted
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: entry.modelData.label
                                        font.family: Core.Theme.fontFamily
                                        font.pixelSize: Core.Theme.fontSize
                                        color: entry.modelData.danger ? Core.Theme.danger : Core.Theme.foreground
                                    }
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const label = entry.modelData.label;
                                        root.closeMenu();
                                        if (label === "Open" && root.svc.selected.length)
                                            root.svc.open(root.svc.selected[0]);
                                        else if (label === "Rename" && root.svc.selected.length === 1)
                                            root.svc.beginRename(root.svc.selected[0]);
                                        else if (label === "Move to Trash")
                                            root.svc.trashSelected();
                                        else if (label === "New Folder")
                                            root.svc.createFolder();
                                        else if (label === "New File")
                                            root.svc.createFile();
                                        else if (label === "Open Desktop")
                                            root.svc.openDesktop();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
