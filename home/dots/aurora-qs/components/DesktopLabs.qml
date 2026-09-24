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

    property bool watching: false

    function syncWatch() {
        if (root.visible === root.watching)
            return;
        if (root.visible)
            root.svc.retain();
        else
            root.svc.release();
        root.watching = root.visible;
    }

    onVisibleChanged: root.syncWatch()
    Component.onCompleted: root.syncWatch()
    Component.onDestruction: {
        if (root.watching)
            root.svc.release();
    }

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
        widgetId: "apps"
        onDesktop: root.onDesktop
        spanW: 4
        spanH: 5
        defaultCol: 8
        defaultRow: 3
        contentComponent: appContent
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
                leadingIcon: Qt.resolvedUrl("../assets/server.svg")
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

        DesktopContainerPanel {
            rows: root.svc.containers
            heading: "Containers"
            emptyHint: "No Docker containers."
            tipMonitor: root.monitorName
        }
    }

    Component {
        id: appContent

        DesktopContainerPanel {
            rows: root.svc.apps
            heading: "System"
            emptyHint: "No system containers."
            tipMonitor: root.monitorName
            appIcons: true
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
                            iconSource: modelData.kind === "amnezia" ? Qt.resolvedUrl("../assets/amnezia.png") : (modelData.kind === "vless" ? Qt.resolvedUrl("../assets/amnezia.png") : Qt.resolvedUrl("../assets/vpn.svg"))
                            title: String(modelData.label || modelData.name || "")
                            subtitle: modelData.up ? "connected" : "disconnected"
                            trailing: modelData.up ? "ON" : "OFF"
                            trailingColor: modelData.up ? Core.Theme.accent : Core.Theme.foregroundMuted
                            active: !!modelData.up
                            busy: root.svc.busyName === modelData.name
                            onActivated: {
                                if (root.svc.busyName === modelData.name)
                                    return;
                                root.svc.toggleVpn(modelData.kind, modelData.name);
                            }
                        }
                    }
                }

                Text {
                    visible: root.svc.vpnItems.length === 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Put *.conf in /etc/wireguard or /etc/amnesia, or *.json in ~/.config/vless (# name / # folder)."
                    color: Core.Theme.foregroundMuted
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeSmall
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    Rectangle {
        id: hoverTip
        readonly property var tip: root.svc.hoverTip
        visible: !!(hoverTip.tip && hoverTip.tip.monitor === root.monitorName)
        enabled: false
        z: 90
        width: tipCol.implicitWidth + 20
        height: tipCol.implicitHeight + 16
        radius: 6
        color: "#000000"
        border.width: 1
        border.color: "#333333"
        x: {
            const t = hoverTip.tip;
            if (!t)
                return 0;
            const p = root.mapFromItem(null, t.x, t.y);
            const nx = p.x + 16;
            if (nx + width > root.width - 8)
                return Math.max(8, p.x - width - 12);
            return Math.max(8, nx);
        }
        y: {
            const t = hoverTip.tip;
            if (!t)
                return 0;
            const p = root.mapFromItem(null, t.x, t.y);
            const ny = p.y + 16;
            if (ny + height > root.height - 8)
                return Math.max(8, p.y - height - 12);
            return Math.max(8, ny);
        }

        Column {
            id: tipCol
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: hoverTip.tip ? hoverTip.tip.lines : []

                Text {
                    required property string modelData
                    width: Math.min(implicitWidth, 340)
                    text: modelData
                    wrapMode: Text.WrapAnywhere
                    color: "#ffffff"
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeSmall
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
