import QtQuick
import Quickshell.Wayland

Item {
    id: root

    property var toplevel: null
    property bool live: false
    enabled: false

    readonly property var handle: root.toplevel && root.toplevel.wayland ? root.toplevel.wayland : null
    readonly property bool ready: shot.hasContent

    ScreencopyView {
        id: shot

        anchors.fill: parent
        captureSource: root.handle
        live: root.live && root.handle
        paintCursor: false
        constraintSize: Qt.size(Math.max(1, root.width), Math.max(1, root.height))
        visible: shot.hasContent
        clip: true
    }

    function capture() {
        if (root.handle)
            shot.captureFrame();
    }

    onToplevelChanged: root.capture()
    Component.onCompleted: root.capture()
}
