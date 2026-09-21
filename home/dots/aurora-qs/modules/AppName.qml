import QtQuick
import Quickshell
import Quickshell.Hyprland

import "../core" as Core
import "../services" as Services
import "../components" as Components

Item {
    id: root

    implicitWidth: Math.min(row.implicitWidth + 16, 296)
    implicitHeight: Core.Theme.moduleHeight
    clip: true

    readonly property string appleLogo: "file://" + Quickshell.shellDir + "/assets/apple.svg"

    readonly property string appTitle: {
        const t = Hyprland.activeToplevel;
        if (!t)
            return "Finder";
        const ipc = t.lastIpcObject || {};
        const cls = String(ipc.class || ipc.initialClass || "");
        const entries = Services.AppsService.entries || [];
        const needle = cls.toLowerCase();
        if (needle.length) {
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i];
                const id = String(e.id || "").toLowerCase();
                const start = String(e.startupClass || "").toLowerCase();
                const name = String(e.name || "");
                if ((start.length && needle.indexOf(start) !== -1) || id.indexOf(needle) !== -1)
                    return name;
            }
        }
        const title = String(t.title || ipc.title || "");
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
        spacing: 8

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            source: root.appleLogo
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            sourceSize.width: 64
            sourceSize.height: 64
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
