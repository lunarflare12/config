import QtQuick
import Quickshell
import Quickshell.Hyprland

import "../core" as Core
import "../services" as Services

Item {
    id: root

    implicitWidth: Math.min(320, Math.max(80, label.implicitWidth + 16))
    implicitHeight: Core.Theme.moduleHeight

    readonly property string appTitle: {
        const t = Hyprland.activeToplevel;
        if (!t)
            return "Desktop";
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
        return "Desktop";
    }

    Text {
        id: label
        anchors.centerIn: parent
        width: parent.width - 8
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        text: root.appTitle
        color: Core.Theme.text
        font.family: Core.Theme.fontFamily
        font.pixelSize: Core.Theme.fontSize
        font.weight: Font.DemiBold
        renderType: Text.QtRendering
    }
}
