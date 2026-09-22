import QtQuick
import QtQuick.Layouts

import "../core" as Core
import "../services" as Services

// Running VMs, containers, and folder-backed VPN tunnels.
Item {
    id: root

    property var modelData: null
    property var host: parent

    readonly property string monitorName: root.host && root.host.monitorName ? root.host.monitorName : ""
    readonly property bool onDesktop: Core.Session.isDesktopMonitor(root.monitorName)
    readonly property var svc: Services.LabService

    anchors.fill: parent
    visible: root.onDesktop

    DesktopWidget {
        host: root.host
        widgetId: "vms"
        onDesktop: root.onDesktop
        spanW: 4
        spanH: 3
        defaultCol: 0
        defaultRow: 3
        contentComponent: vmContent
    }

    DesktopWidget {
        host: root.host
        widgetId: "containers"
        onDesktop: root.onDesktop
        spanW: 4
        spanH: 4
        defaultCol: 4
        defaultRow: 3
        contentComponent: containerContent
    }

    DesktopWidget {
        host: root.host
        widgetId: "vpn"
        onDesktop: root.onDesktop
        spanW: 4
        spanH: 5
        defaultCol: 0
        defaultRow: 6
        contentComponent: vpnContent
    }

    Component {
        id: vmContent

        ColumnLayout {
            anchors.fill: parent
            spacing: Core.Theme.spacing

            PopupHeader {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                title: "Virtual machines"
                subtitle: root.svc.vmCount === 0 ? "None running" : (root.svc.vmCount + " running")
                showToggle: false
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Core.Theme.separator
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: vmCol.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: vmCol
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.svc.vms

                        ListRow {
                            required property var modelData
                            width: vmCol.width
                            iconSource: Qt.resolvedUrl("../assets/server.svg")
                            title: String(modelData.name || "")
                            subtitle: String(modelData.state || "running")
                            trailing: "ON"
                            trailingColor: Core.Theme.accent
                            active: true
                            onActivated: root.svc.openVm(modelData.name)
                        }
                    }

                    Text {
                        visible: root.svc.vmCount === 0
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "No running libvirt guests."
                        color: Core.Theme.foregroundMuted
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: Core.Theme.fontSizeSmall
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }

    Component {
        id: containerContent

        Item {
            id: panel

            property var hoverCt: null
            property var menuCt: null
            property bool menuOpen: false
            property real menuX: 0
            property real menuY: 0

            function tipText(ct) {
                if (!ct)
                    return "";
                if (ct.state === "paused")
                    return "paused";
                if (ct.state && ct.state !== "running")
                    return String(ct.status || ct.state);
                const cpu = String(ct.cpu || "—");
                const mem = String(ct.mem || "—");
                return "CPU " + cpu + "  ·  RAM " + mem;
            }

            function openMenu(row, ct) {
                panel.menuCt = ct;
                const p = row.mapToItem(panel, row.width - 8, 0);
                panel.menuX = p.x;
                panel.menuY = p.y;
                Qt.callLater(function () {
                    panel.menuOpen = true;
                });
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Core.Theme.spacing

                PopupHeader {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    title: "Containers"
                    leadingIcon: Qt.resolvedUrl("../assets/docker.svg")
                    subtitle: {
                        const n = root.svc.containerCount;
                        if (n === 0)
                            return "None";
                        return n + " total";
                    }
                    showToggle: false
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Core.Theme.separator
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        id: ctFlick
                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: ctCol.height
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        interactive: true

                        Column {
                            id: ctCol
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: root.svc.containers

                                ListRow {
                                    id: ctRow
                                    required property var modelData
                                    width: ctCol.width
                                    iconSource: Qt.resolvedUrl("../assets/docker.svg")
                                    title: String(modelData.name || "")
                                    subtitle: String(modelData.image || modelData.status || "")
                                    trailing: modelData.state === "running" ? "ON" : (modelData.state === "paused" ? "PAUSE" : "OFF")
                                    trailingColor: modelData.state === "running" ? Core.Theme.accent : Core.Theme.foregroundMuted
                                    active: modelData.state === "running"
                                    dimmed: modelData.state !== "running"
                                    busy: root.svc.busy && panel.menuCt && panel.menuCt.name === modelData.name
                                    onHoveredChanged: {
                                        if (ctRow.hovered)
                                            panel.hoverCt = modelData;
                                        else if (panel.hoverCt && panel.hoverCt.name === modelData.name)
                                            panel.hoverCt = null;
                                    }
                                    onActivated: panel.openMenu(ctRow, modelData)
                                    onContextRequested: root.svc.togglePause(modelData)
                                }
                            }

                            Text {
                                visible: root.svc.containerCount === 0
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "No Docker containers."
                                color: Core.Theme.foregroundMuted
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: Core.Theme.fontSizeSmall
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    Rectangle {
                        visible: ctFlick.contentHeight > ctFlick.height + 8
                        width: 3
                        radius: 2
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        x: parent.width - width - 2
                        height: Math.max(18, ctFlick.height * ctFlick.height / Math.max(ctFlick.contentHeight, 1))
                        y: {
                            const extra = Math.max(1, ctFlick.contentHeight - ctFlick.height);
                            return (ctFlick.height - height) * ctFlick.contentY / extra;
                        }
                        color: Qt.alpha(Core.Theme.foreground, 0.5)
                    }
                }
            }

            Rectangle {
                visible: !!panel.hoverCt && !panel.menuOpen
                z: 40
                width: tipLabel.implicitWidth + 16
                height: tipLabel.implicitHeight + 12
                radius: 8
                x: Math.max(8, parent.width - width - 10)
                y: 36
                color: Qt.alpha(Core.Theme.background, 0.94)
                border.width: 1
                border.color: Core.Theme.borderActive

                Text {
                    id: tipLabel
                    anchors.centerIn: parent
                    text: panel.tipText(panel.hoverCt)
                    color: Core.Theme.foreground
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeSmall
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: panel.menuOpen
                z: 49
                onClicked: panel.menuOpen = false
            }

            Rectangle {
                id: ctMenu
                visible: panel.menuOpen && panel.menuCt
                z: 50
                width: 196
                height: menuCol.implicitHeight + 10
                x: Math.max(8, Math.min(parent.width - width - 8, panel.menuX - width))
                y: Math.max(8, Math.min(parent.height - height - 8, panel.menuY))
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
                            { "label": "Enter", "icon": Core.Icons.terminal, "act": "enter" },
                            { "label": "Restart", "icon": Core.Icons.restart, "act": "restart" },
                            { "label": "Copy image", "icon": Core.Icons.clipboard, "act": "copy" },
                            { "sep": true },
                            { "label": "Delete", "icon": Core.Icons.trash, "act": "rm", "danger": true }
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
                                            font.hintingPreference: Font.PreferNoHinting
                                            renderType: Text.QtRendering
                                            color: entry.modelData.danger ? Core.Theme.danger : Core.Theme.foreground
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: entry.modelData.label || ""
                                            color: entry.modelData.danger ? Core.Theme.danger : Core.Theme.foreground
                                            font.family: Core.Theme.fontFamily
                                            font.pixelSize: Core.Theme.fontSize
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const ct = panel.menuCt;
                                            const act = entry.modelData.act;
                                            panel.menuOpen = false;
                                            if (!ct)
                                                return;
                                            if (act === "enter")
                                                root.svc.enterContainer(ct.name);
                                            else if (act === "restart")
                                                root.svc.restartContainer(ct.name);
                                            else if (act === "copy")
                                                root.svc.copyImage(ct.image);
                                            else if (act === "rm")
                                                root.svc.removeContainer(ct.name);
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

    Component {
        id: vpnContent

        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: vpnCol.height
            boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: vpnCol
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.svc.vpnItems

                        Item {
                            required property var modelData
                            width: vpnCol.width
                            height: row.visible ? row.implicitHeight : folderHead.implicitHeight + 4

                            Column {
                                id: folderHead
                                width: parent.width
                                visible: modelData.item === "folder"
                                spacing: 6

                                Text {
                                    width: parent.width
                                    text: String(modelData.name || "")
                                    color: Core.Theme.foregroundMuted
                                    font.family: Core.Theme.fontFamily
                                    font.pixelSize: Core.Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Core.Theme.separator
                                }
                            }

                            ListRow {
                                id: row
                                width: parent.width
                                visible: modelData.item === "tunnel"
                                iconSource: modelData.kind === "amnezia" ? Qt.resolvedUrl("../assets/amnezia.png") : Qt.resolvedUrl("../assets/vpn.svg")
                                title: String(modelData.label || modelData.name || "")
                                subtitle: modelData.up ? "connected" : "disconnected"
                                trailing: modelData.up ? "ON" : "OFF"
                                trailingColor: modelData.up ? Core.Theme.accent : Core.Theme.foregroundMuted
                                active: !!modelData.up
                                busy: root.svc.busy
                                onActivated: root.svc.toggleVpn(modelData.kind, modelData.name)
                            }
                        }
                    }

                Text {
                    visible: root.svc.vpnItems.length === 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Put *.conf in /etc/wireguard or /etc/amnesia, then click to connect."
                    color: Core.Theme.foregroundMuted
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeSmall
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
