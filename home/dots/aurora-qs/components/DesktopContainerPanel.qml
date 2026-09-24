import QtQuick
import QtQuick.Layouts

import "../core" as Core
import "../services" as Services

Item {
    id: panel

    property var svc: Services.LabService
    property var rows: []
    property string heading: "Containers"
    property string emptyHint: "No Docker containers."
    property bool appIcons: false

    property string tipMonitor: ""
    property var hoverCt: null
    property var menuCt: null
    property bool menuOpen: false
    property real menuX: 0
    property real menuY: 0

    function placeTip(row, mx, my, ct) {
        if (!row || !ct)
            return;
        const p = row.mapToItem(null, mx, my);
        panel.svc.showHoverTip(ct, p.x, p.y, panel.tipMonitor);
    }

    function openMenu(row, ct) {
        panel.menuCt = ct;
        panel.svc.hideHoverTip(ct ? ct.name : "");
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
            title: panel.heading
            leadingIcon: Qt.resolvedUrl("../assets/docker.svg")
            subtitle: {
                const n = panel.rows ? panel.rows.length : 0;
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
                        model: panel.rows

                        ListRow {
                            id: ctRow
                            required property var modelData
                            width: ctCol.width
                            iconSource: panel.appIcons ? Services.AppsService.iconForContainer(modelData.name) : Qt.resolvedUrl("../assets/docker.svg")
                            title: String(modelData.name || "")
                            subtitle: String(modelData.image || modelData.status || "")
                            trailing: modelData.state === "running" ? "ON" : (modelData.state === "paused" ? "PAUSE" : "OFF")
                            trailingColor: modelData.state === "running" ? Core.Theme.accent : Core.Theme.foregroundMuted
                            active: modelData.state === "running"
                            dimmed: modelData.state !== "running"
                            busy: panel.svc.busyName === modelData.name
                            onHoveredChanged: {
                                if (ctRow.hovered) {
                                    panel.hoverCt = modelData;
                                    return;
                                }
                                if (panel.hoverCt && panel.hoverCt.name === modelData.name)
                                    panel.hoverCt = null;
                                panel.svc.hideHoverTip(modelData.name);
                            }
                            onHoverMoved: function (mx, my) {
                                panel.hoverCt = modelData;
                                if (!panel.menuOpen)
                                    panel.placeTip(ctRow, mx, my, modelData);
                            }
                            onActivated: panel.svc.toggleRun(modelData)
                            onContextRequested: panel.openMenu(ctRow, modelData)
                        }
                    }

                    Text {
                        visible: !panel.rows || panel.rows.length === 0
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: panel.emptyHint
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
                height: Math.max(18, ctFlick.height * ctFlick.height / Math.max(ctFlick.contentHeight, 1))
                y: {
                    const extra = Math.max(1, ctFlick.contentHeight - ctFlick.height);
                    return (ctFlick.height - height) * ctFlick.contentY / extra;
                }
                color: Qt.alpha(Core.Theme.foreground, 0.5)
            }
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
                            {
                                "label": panel.menuCt && panel.menuCt.state === "running" ? "Stop" : "Start",
                                "icon": Core.Icons.power,
                                "act": "run"
                            },
                            {
                                "label": "Restart",
                                "icon": Core.Icons.restart,
                                "act": "restart"
                            },
                            {
                                "sep": true
                            },
                            {
                                "label": "Enter",
                                "icon": Core.Icons.terminal,
                                "act": "enter"
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
                                            if (act === "run")
                                                panel.svc.toggleRun(ct);
                                            else if (act === "restart")
                                                panel.svc.restartContainer(ct.name);
                                            else if (act === "enter")
                                                panel.svc.enterContainer(ct.name);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
