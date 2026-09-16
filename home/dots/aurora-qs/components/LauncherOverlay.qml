import QtQuick

import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../modules" as Modules
import "../services" as Services

// One overlay per monitor, always mapped, so Super+R does not wait for a new surface.
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
    visible: true
    exclusiveZone: 0

    WlrLayershell.namespace: "aurora-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property Region emptyMask: Region {
        width: 0
        height: 0
    }

    mask: (root.launcherOpen || root.intro > 0.01) ? null : root.emptyMask

    readonly property bool onFocused: Core.Session.monitorNameForScreen(root.screen) === Core.Session.focusedMonitorName()

    property bool host: false
    property real intro: 0
    property bool closingLaunchpad: false

    readonly property var launchers: [appLauncher, wallpaperPicker, themePicker, clipboardView, emojiPicker, powerMenu]

    readonly property var activeLauncher: {
        const list = root.launchers;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].open)
                return list[i];
        }
        return null;
    }

    readonly property bool launcherOpen: root.host && root.activeLauncher !== null
    readonly property bool launchpadOpen: root.host && appLauncher.open
    readonly property bool showLaunchpad: root.launchpadOpen || (root.closingLaunchpad && root.intro > 0.01)
    readonly property bool showCard: root.launcherOpen && !root.showLaunchpad

    Behavior on intro {
        NumberAnimation {
            duration: root.launchpadOpen ? 220 : 140
            easing.type: root.launchpadOpen ? Easing.OutCubic : Easing.InCubic
        }
    }

    Connections {
        target: Core.PopupManager
        function onCurrentChanged() {
            const cur = Core.PopupManager.current;
            if (cur !== "") {
                root.host = root.onFocused;
                root.closingLaunchpad = false;
                root.intro = (root.host && cur === "launcher") ? 1 : 0;
                return;
            }
            if (root.intro > 0.01) {
                root.closingLaunchpad = true;
                root.intro = 0;
                return;
            }
            root.host = false;
            root.closingLaunchpad = false;
        }
    }

    onIntroChanged: {
        if (root.host || root.closingLaunchpad)
            Core.PopupManager.launchpadIntro = root.intro;
        if (root.intro <= 0.01 && Core.PopupManager.current === "") {
            root.closingLaunchpad = false;
            root.host = false;
            Core.PopupManager.launchpadIntro = 0;
            Services.AppsService.clearDockDrop();
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.launcherOpen
        acceptedButtons: Qt.LeftButton
        onClicked: Core.PopupManager.close()
    }

    Item {
        id: frost
        anchors.fill: parent
        opacity: Math.min(1, root.intro)
        visible: root.intro > 0.01
        clip: true

        Image {
            anchors.fill: parent
            source: Services.WallpaperService.current ? ("file://" + Services.WallpaperService.current) : ""
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            sourceSize.width: Math.max(160, Math.round(root.width / 10))
            sourceSize.height: Math.max(90, Math.round(root.height / 10))
            smooth: true
            scale: 1.02 + 0.06 * root.intro
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.08, 0.08, 0.10, 0.34)
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, 0.08)
        }
    }

    Image {
        visible: false
        asynchronous: true
        cache: true
        source: Services.WallpaperService.current ? ("file://" + Services.WallpaperService.current) : ""
        sourceSize.width: 320
        sourceSize.height: 180
    }

    Modules.AppLauncher {
        id: appLauncher
        anchors.fill: parent
        anchors.bottomMargin: 96
        z: 2
        intro: root.intro
        opacity: root.showLaunchpad ? 1 : 0
        dockTarget: launchpadDock
    }

    DockBar {
        id: launchpadDock
        z: 4
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        intro: root.showLaunchpad ? root.intro : 0
        visible: root.showLaunchpad && root.intro > 0.01
        interactive: true
        onLaunched: Core.PopupManager.close()
    }

    Image {
        z: 50
        visible: root.showLaunchpad && appLauncher.dragging && appLauncher.dragFrom >= 0 && appLauncher.dragFrom < appLauncher.itemCount
        width: 88
        height: 88
        x: appLauncher.dragX - width / 2
        y: appLauncher.dragY - height / 2
        source: {
            if (!appLauncher.dragging)
                return "";
            const e = appLauncher.results[appLauncher.dragFrom];
            return e ? Services.AppsService.iconSource(e) : "";
        }
        fillMode: Image.PreserveAspectFit
        smooth: true
        cache: true
        opacity: 0.92
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((root.height - height) * 0.18)

        width: root.activeLauncher ? root.activeLauncher.cardWidth : 460
        height: root.activeLauncher ? root.activeLauncher.viewHeight : 110
        radius: Core.Theme.radiusMenu
        color: "transparent"
        antialiasing: true
        clip: true
        visible: root.showCard
        z: 3

        Rectangle {
            anchors.fill: parent
            anchors.margins: -Core.Theme.borderWidth
            radius: parent.radius + Core.Theme.borderWidth
            color: "transparent"
            border.width: Core.Theme.borderWidth
            border.color: Core.Theme.borderActive
            antialiasing: true
        }

        Glass {
            anchors.fill: parent
            radius: parent.radius
            strength: 1.0
        }

        Item {
            anchors.fill: parent

            Modules.WallpaperPicker {
                id: wallpaperPicker
                anchors.fill: parent
            }

            Modules.ThemePicker {
                id: themePicker
                anchors.fill: parent
            }

            Modules.Clipboard {
                id: clipboardView
                anchors.fill: parent
            }

            Modules.EmojiPicker {
                id: emojiPicker
                anchors.fill: parent
            }

            Modules.PowerMenu {
                id: powerMenu
                anchors.fill: parent
            }
        }
    }
}
