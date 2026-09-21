import QtQuick
import QtQuick.Window
import Quickshell.Wayland

Item {
    id: root

    property var toplevel: null
    property bool live: false
    enabled: false

    readonly property var handle: root.toplevel && root.toplevel.wayland ? root.toplevel.wayland : null
    readonly property bool onScreen: {
        const win = root.Window.window;
        return !!(root.visible && win && win.visible && root.handle);
    }
    readonly property bool ready: shot.hasContent

    ScreencopyView {
        id: shot

        anchors.fill: parent
        captureSource: root.onScreen ? root.handle : null
        live: root.onScreen
        paintCursor: false
        constraintSize: Qt.size(Math.max(1, root.width), Math.max(1, root.height))
        visible: shot.hasContent
        clip: true
    }
}
