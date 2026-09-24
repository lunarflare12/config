import QtQuick
import Quickshell.Hyprland

import "../core" as Core
import "../services" as Services
import "../components" as Components

Item {
    id: root

    implicitWidth: Math.min(row.implicitWidth + 16, 296)
    implicitHeight: Core.Theme.moduleHeight
    clip: true

    readonly property string appTitle: {
        const _ = Core.Session.fsTick;
        const liveClass = Core.Session.activeWindowClass;
        const liveTitle = Core.Session.activeWindowTitle;
        const t = Hyprland.activeToplevel;
        const ipc = t && t.lastIpcObject ? t.lastIpcObject : {};
        const cls = String(liveClass || ipc.class || ipc.initialClass || "");
        const named = Services.AppsService.nameForClass(cls, "");
        if (named && named !== cls)
            return named;
        const title = String(liveTitle || (t && t.title) || ipc.title || "");
        if (title.length)
            return title;
        if (cls.length)
            return cls;
        return "Finder";
    }

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
        spacing: 6

        Components.ThemeIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "arch"
            width: 16
            height: 16
        }

        Text {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.appTitle
            color: Core.Theme.text
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSize
            font.weight: Font.DemiBold
            renderType: Text.QtRendering
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
