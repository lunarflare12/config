import QtQuick
import Quickshell.Hyprland

import "../core" as Core
import "../services" as Services

// Shared glass dock tray. Used on the desktop and inside Launchpad.
Item {
    id: tray

    property real intro: 1
    property bool interactive: true

    readonly property var pinned: Services.AppsService.dockEntries || []
    readonly property bool dropping: Services.AppsService.dockDropActive
    readonly property int dropSlot: Services.AppsService.dockHoverSlot

    property int dragFrom: -1
    property int hoverSlot: -1
    property real dragX: 0
    property real dragY: 0
    property bool holding: false
    property bool menuOpen: false
    property int hoverIndex: -1
    property bool trashHover: false
    readonly property bool dragging: tray.dragFrom >= 0

    signal launched

    implicitWidth: dockBody.width
    implicitHeight: 74
    width: implicitWidth
    height: implicitHeight
    clip: false

    readonly property Item hitbox: hit

    opacity: tray.intro
    scale: 0.86 + 0.14 * tray.intro
    transformOrigin: Item.Bottom

    transform: Translate {
        y: (1 - tray.intro) * 56
    }

    onIntroChanged: {
        if (tray.intro < 0.5)
            tray.menuOpen = false;
    }

    onMenuOpenChanged: Core.PopupManager.contextMenuOpen = tray.menuOpen

    Connections {
        target: Core.PopupManager
        function onContextMenuOpenChanged() {
            if (!Core.PopupManager.contextMenuOpen)
                tray.menuOpen = false;
        }
    }

    function resetPointer() {
        tray.dragFrom = -1;
        tray.hoverSlot = -1;
        tray.holding = false;
        tray.hoverIndex = -1;
        tray.trashHover = false;
    }

    function finishDrag(unpinId, from, to) {
        tray.resetPointer();
        if (unpinId) {
            Qt.callLater(function () {
                Services.AppsService.unpinDock(unpinId);
            });
            return;
        }
        if (from >= 0 && to >= 0)
            Services.AppsService.moveDock(from, to);
    }

    function containsApps(x, y) {
        const p = tray.mapToItem(iconsRow, x, y);
        return p.x >= -8 && p.x <= iconsRow.width + 8 && p.y >= -16 && p.y <= iconsRow.height + 16;
    }

    function slotAt(x, y) {
        const n = tray.pinned.length;
        if (n === 0)
            return 0;
        const p = tray.mapToItem(iconsRow, x, y);
        const w = Math.max(1, iconsRow.width);
        const t = Math.max(0, Math.min(1, p.x / w));
        return Math.round(t * n);
    }

    Item {
        id: hit
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: dockBody.width
        height: 74 + (tray.menuOpen ? trashMenu.height + 10 : 0)

        Item {
            id: dockBody
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(96, dockRow.implicitWidth + 28)
        height: 68

        Glass {
            anchors.fill: parent
            radius: 22
            strength: 1.0
        }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "transparent"
            border.width: tray.dropping ? 2 : 0
            border.color: Qt.rgba(1, 1, 1, 0.55)
        }

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 0

            Row {
                id: iconsRow
                spacing: 4

                Repeater {
                    model: tray.pinned.length

                    Item {
                        id: slot
                        required property int index
                        readonly property var modelData: tray.pinned[slot.index]
                        width: 54
                        height: 60
                        opacity: tray.dragging && tray.dragFrom === slot.index ? 0.28 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: tray.dropping && tray.dropSlot === slot.index ? Qt.rgba(1, 1, 1, 0.20) : "transparent"
                        }

                        Image {
                            id: icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            width: 44
                            height: 44
                            source: Services.AppsService.iconSource(slot.modelData)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            cache: true
                            sourceSize.width: 128
                            sourceSize.height: 128
                            scale: tray.interactive && !tray.dragging && !tray.holding && !tray.dropping && tray.hoverIndex === slot.index ? 1.38 : 1.0
                            transformOrigin: Item.Bottom

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            width: 4
                            height: 4
                            radius: 2
                            color: Core.Theme.text
                            opacity: slot.running ? 0.9 : 0
                        }

                        readonly property bool running: {
                            const tops = Hyprland.toplevels ? Hyprland.toplevels.values : [];
                            const name = String(slot.modelData && slot.modelData.name || "").toLowerCase();
                            const cls = String(slot.modelData && (slot.modelData.startupClass || slot.modelData.startupWmClass || "") || "").toLowerCase();
                            for (let i = 0; i < tops.length; i++) {
                                const ipc = tops[i].lastIpcObject || {};
                                const c = String(ipc.class || ipc.initialClass || "").toLowerCase();
                                const t = String(tops[i].title || ipc.title || "").toLowerCase();
                                if ((cls.length && c.indexOf(cls) !== -1) || (name.length && (c.indexOf(name) !== -1 || t.indexOf(name) !== -1)))
                                    return true;
                            }
                            return false;
                        }

                        MouseArea {
                            id: iconMouse
                            anchors.fill: parent
                            enabled: tray.interactive
                            hoverEnabled: tray.interactive
                            cursorShape: tray.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            property real pressX: 0
                            property real pressY: 0
                            property bool dragged: false

                            onEntered: {
                                if (!tray.dragging && !tray.holding)
                                    tray.hoverIndex = slot.index;
                            }
                            onExited: {
                                if (tray.hoverIndex === slot.index)
                                    tray.hoverIndex = -1;
                            }
                            onPressed: function (mouse) {
                                pressX = mouse.x;
                                pressY = mouse.y;
                                dragged = false;
                                tray.holding = true;
                                tray.hoverIndex = slot.index;
                            }
                            onPositionChanged: function (mouse) {
                                if (!iconMouse.pressed)
                                    return;
                                if (!dragged && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 8) {
                                    dragged = true;
                                    tray.dragFrom = slot.index;
                                    tray.hoverSlot = slot.index;
                                    tray.hoverIndex = -1;
                                }
                                if (!dragged)
                                    return;
                                const p = iconMouse.mapToItem(tray, mouse.x, mouse.y);
                                tray.dragX = p.x;
                                tray.dragY = p.y;
                                const r = iconMouse.mapToItem(iconsRow, mouse.x, mouse.y);
                                const hit = iconsRow.childAt(r.x, r.y);
                                if (hit && hit.index !== undefined)
                                    tray.hoverSlot = hit.index;
                            }
                            onReleased: function (mouse) {
                                if (dragged && tray.dragFrom >= 0) {
                                    const p = iconMouse.mapToItem(dockBody, mouse.x, mouse.y);
                                    const from = tray.dragFrom;
                                    const to = tray.hoverSlot;
                                    const unpin = p.y < -28 || p.y > dockBody.height + 28;
                                    const id = slot.modelData && slot.modelData.id;
                                    dragged = false;
                                    tray.finishDrag(unpin ? id : "", from, unpin ? -1 : to);
                                    return;
                                }
                                dragged = false;
                                tray.resetPointer();
                                Services.AppsService.launch(slot.modelData);
                                tray.launched();
                            }
                            onCanceled: {
                                dragged = false;
                                tray.resetPointer();
                            }
                        }
                    }
                }

                Item {
                    width: 8
                    height: 60
                    visible: tray.dropping && tray.dropSlot >= tray.pinned.length

                    Rectangle {
                        anchors.centerIn: parent
                        width: 3
                        height: 36
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }
            }

            Item {
                width: 18
                height: 60

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    width: 1
                    height: 28
                    radius: 1
                    color: Qt.rgba(1, 1, 1, 0.32)
                }
            }

            Item {
                id: trashSlot
                width: 54
                height: 60

                Image {
                    id: trashIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: 44
                    height: 44
                    source: Services.DesktopService.trashIcon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    cache: true
                    sourceSize.width: 128
                    sourceSize.height: 128
                    scale: tray.interactive && !tray.dragging && !tray.holding && tray.trashHover ? 1.38 : 1.0
                    transformOrigin: Item.Bottom

                    Behavior on scale {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: trashMouse
                    anchors.fill: parent
                    enabled: tray.interactive
                    hoverEnabled: tray.interactive
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: tray.trashHover = !tray.dragging && !tray.holding
                    onExited: tray.trashHover = false
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) {
                            tray.menuOpen = true;
                            return;
                        }
                        tray.menuOpen = false;
                        Services.DesktopService.openTrash();
                        tray.launched();
                    }
                }
            }
        }

        Image {
            visible: tray.dragging && tray.dragFrom >= 0 && tray.dragFrom < tray.pinned.length
            z: 20
            width: 52
            height: 52
            x: tray.dragX - width / 2
            y: tray.dragY - height / 2
            source: {
                if (!tray.dragging)
                    return "";
                const e = tray.pinned[tray.dragFrom];
                return e ? Services.AppsService.iconSource(e) : "";
            }
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: true
        }
    }

    Rectangle {
        id: trashMenu
        visible: tray.menuOpen
        z: 40
        width: 188
        height: menuCol.implicitHeight + 10
        anchors.right: dockBody.right
        anchors.bottom: dockBody.top
        anchors.bottomMargin: 8
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
                model: [
                    { "label": "Open", "icon": Core.Icons.folder, "action": "open", "enabled": true, "danger": false },
                    { "label": "Empty Trash", "icon": Core.Icons.trash, "action": "empty", "enabled": Services.DesktopService.trashFull, "danger": true }
                ]

                Rectangle {
                    id: row
                    required property var modelData
                    width: menuCol.width
                    height: 30
                    radius: Core.Theme.radiusRow
                    color: "transparent"
                    opacity: row.modelData.enabled ? 1 : 0.42

                    Tactile {
                        anchors.fill: parent
                        radius: Core.Theme.radiusRow
                        hovered: rowMouse.containsMouse && row.modelData.enabled
                        pressed: rowMouse.pressed && row.modelData.enabled
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
                            text: row.modelData.icon
                            font.family: Core.Theme.iconFont
                            font.pixelSize: Core.Theme.iconSizeSmall
                            color: row.modelData.danger ? Core.Theme.danger : Core.Theme.foregroundMuted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: Core.Theme.fontSize
                            color: row.modelData.danger ? Core.Theme.danger : Core.Theme.foreground
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: row.modelData.enabled
                        cursorShape: row.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const action = row.modelData.action;
                            tray.menuOpen = false;
                            if (action === "open") {
                                Services.DesktopService.openTrash();
                                tray.launched();
                            } else if (action === "empty") {
                                Services.DesktopService.emptyTrash();
                            }
                        }
                    }
                }
            }
        }
    }
}
}
