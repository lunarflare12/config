import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

// Right-edge audio drawer from Brain Shell.
PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property bool mine: Core.PopupManager.anchorScreen ? Core.PopupManager.anchorScreen === root.screen : Core.Session.monitorNameForScreen(root.screen) === Core.Session.focusedMonitorName()
    readonly property bool open: Core.PopupManager.isOpen("edge-audio") && root.mine
    readonly property var svc: Services.AudioService

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open
    exclusiveZone: 0

    WlrLayershell.namespace: "aurora-edge-audio"
    WlrLayershell.layer: WlrLayer.Overlay

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: Core.PopupManager.close()
    }

    Item {
        id: sheet
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.open ? 280 : 0
        height: 360
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            onHoveredChanged: Core.PopupManager.setDrawerHover("edge-audio", hovered)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupShape {
            anchors.fill: parent
            attachedEdge: "right"
        }

        Column {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: Core.Theme.frameRadius + 14
            anchors.topMargin: Core.Theme.frameRadius + 14
            anchors.bottomMargin: Core.Theme.frameRadius + 14
            spacing: 10
            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }

            Row {
                width: parent.width
                spacing: 8

                ThemeIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Core.Icons.volumeTheme(root.svc.volume, root.svc.muted)
                    width: 18
                    height: 18
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.svc.muted ? "Muted" : (root.svc.volumePercent + "%")
                    color: Core.Theme.text
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
            }

            VolumeSlider {
                width: parent.width
                value: root.svc.volume
                muted: root.svc.muted
                onMoved: function (v) {
                    root.svc.setVolume(root.svc.sink, v);
                }
            }

            Text {
                text: "Output"
                color: Core.Theme.textMuted
                font.pixelSize: 11
            }

            Flickable {
                width: parent.width
                height: parent.height - 120
                clip: true
                contentHeight: sinkCol.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: sinkCol
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.svc.sinks

                        delegate: Rectangle {
                            required property var modelData
                            width: sinkCol.width
                            height: 34
                            radius: 8
                            color: root.svc.isDefault(modelData) ? Qt.alpha(Core.Theme.accent, 0.2) : (rowHov.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                            Text {
                                anchors.fill: parent
                                anchors.margins: 8
                                text: root.svc.label(modelData)
                                color: root.svc.isDefault(modelData) ? Core.Theme.accent : Core.Theme.text
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 12
                            }

                            HoverHandler {
                                id: rowHov
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.svc.setDefault(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
