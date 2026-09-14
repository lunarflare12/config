import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property real dim: {
        const _ = Services.BrightnessService.levels;
        return Services.BrightnessService.dimOf(root.monitorName);
    }
    readonly property bool gameFullscreen: Core.Session.gameFullscreenOnScreen(root.screen)

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: Qt.rgba(0, 0, 0, root.dim)
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    visible: root.dim > 0.01 && !root.gameFullscreen

    WlrLayershell.namespace: "aurora-dim"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        width: 0
        height: 0
    }
}
