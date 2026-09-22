import QtQuick
import Quickshell.Wayland

Item {
    id: root

    property var toplevel: null
    property bool live: false
    enabled: false

    readonly property var handle: root.toplevel && root.toplevel.wayland ? root.toplevel.wayland : null
    readonly property bool ready: shot.hasContent
    readonly property bool canCapture: !!(root.visible && root.opacity > 0.02 && root.width >= 2 && root.height >= 2 && root.handle)

    ScreencopyView {
        id: shot

        anchors.fill: parent
        captureSource: root.canCapture ? root.handle : null
        live: root.canCapture && root.live
        paintCursor: false
        constraintSize: Qt.size(Math.max(1, Math.round(root.width)), Math.max(1, Math.round(root.height)))
        visible: shot.hasContent
        clip: true
    }
}
