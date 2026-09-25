import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

// Per-monitor software dim. Hyprsunset gamma is global and blacks out every
// output at once, so brightness lives here instead.
PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    visible: root.dim > 0.01

    WlrLayershell.namespace: "aurora-dim"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property Region emptyMask: Region {
        width: 0
        height: 0
    }

    mask: root.emptyMask

    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property real dim: Services.BrightnessService.dimOf(root.monitorName)

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.dim
    }
}
