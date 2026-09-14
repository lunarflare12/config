import QtQuick

import "../core" as Core
import "../services" as Services
import "../components" as Components

Item {
    id: root

    property var screen: null

    implicitWidth: Math.max(30, row.implicitWidth + 8)
    implicitHeight: Core.Theme.moduleHeight

    readonly property var svc: Services.ShaderService
    readonly property bool menuOpen: Core.PopupManager.isOpen("shaders")
    readonly property bool stale: root.svc.stale
    readonly property bool building: root.svc.building
    readonly property bool updating: root.svc.updating
    readonly property string barKind: root.svc.barKind
    readonly property int percent: Math.round(root.svc.barPercent)
    readonly property bool showPercent: root.barKind === "download" || root.barKind === "compile"
    readonly property color valueColor: {
        if (root.barKind === "download" || root.barKind === "patch")
            return Core.Theme.error;
        if (root.building || root.barKind === "compile")
            return Core.Theme.accent;
        if (root.stale)
            return Core.Theme.warning;
        return root.menuOpen ? Core.Theme.accent : Core.Theme.foreground;
    }

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.menuOpen
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.building || root.barKind === "compile"
            text: Core.Icons.spinner
            color: root.valueColor
            font.family: Core.Theme.iconFont
            font.pixelSize: Core.Theme.iconSize
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.QtRendering

            RotationAnimator on rotation {
                running: root.building || root.barKind === "compile"
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !(root.building || root.barKind === "compile")
            text: root.barKind === "download" ? Core.Icons.download : Core.Icons.gamepad
            color: root.valueColor
            font.family: Core.Theme.iconFont
            font.pixelSize: Core.Theme.iconSize
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.QtRendering
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showPercent
            text: root.percent + "%"
            color: root.valueColor
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeSmall
            font.weight: Font.Medium
            renderType: Text.QtRendering
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: {
            Services.ShaderService.toggleOn(Core.Session.monitorNameForScreen(root.screen));
        }
    }
}
