import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

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
    visible: true

    WlrLayershell.namespace: "aurora-splash"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property Region emptyMask: Region {
        width: 0
        height: 0
    }

    mask: root.open || root.intro > 0.01 ? splashMask : root.emptyMask

    property Region splashMask: Region {
        item: frame
    }

    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property bool gameFullscreen: Core.Session.gameFullscreenOnScreen(root.screen)
    readonly property bool mine: Services.LaunchSplash.shown && Services.LaunchSplash.monitorName === root.monitorName && !root.gameFullscreen
    readonly property bool open: root.mine
    property real intro: 0

    readonly property int leftPad: Core.Session.isDesktopMonitor(root.monitorName) ? Core.Theme.dockReserve + 10 : 10
    readonly property int topPad: Core.Theme.barHeight + 4
    readonly property int rightPad: 10
    readonly property int bottomPad: 10

    onMineChanged: root.intro = root.mine ? 1 : 0
    onIntroChanged: {
        if (root.intro <= 0.01 && !Services.LaunchSplash.shown)
            Services.LaunchSplash.release();
    }

    Behavior on intro {
        NumberAnimation {
            duration: root.mine ? 180 : 220
            easing.type: root.mine ? Easing.OutCubic : Easing.InCubic
        }
    }

    Item {
        id: frame
        anchors.fill: parent
        anchors.leftMargin: root.leftPad
        anchors.topMargin: root.topPad
        anchors.rightMargin: root.rightPad
        anchors.bottomMargin: root.bottomPad
        visible: root.intro > 0.01
        opacity: root.intro
        scale: 0.985 + root.intro * 0.015
        transformOrigin: Item.Center

        WindowSkeleton {
            anchors.fill: parent
            kind: Services.LaunchSplash.kind
            icon: Services.LaunchSplash.icon
            title: Services.LaunchSplash.appName
            playing: root.intro > 0.01
        }
    }

    ScreencopyView {
        id: shot
        width: 64
        height: 64
        visible: false
        captureSource: root.mine ? Services.LaunchSplash.handle : null
        live: root.mine && Services.LaunchSplash.handle !== null
        paintCursor: false
        constraintSize: Qt.size(64, 64)
    }

    readonly property bool frameReady: shot.hasContent
    onFrameReadyChanged: {
        if (root.frameReady)
            Services.LaunchSplash.markPainted();
    }
}
