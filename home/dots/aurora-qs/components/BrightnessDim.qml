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

    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    visible: !root.gameFullscreen && (root.dim > 0.001 || shade.opacity > 0.001)

    Rectangle {
        id: shade

        anchors.fill: parent
        color: "black"
        opacity: root.dim

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    WlrLayershell.namespace: "aurora-dim"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        width: 0
        height: 0
    }
}
