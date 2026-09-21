import QtQuick

import QtQuick.Effects

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

    // Opaque while the menu is up so live windows cannot show through.
    color: root.intro > 0.01 ? "#101014" : (root.stripOpen ? Qt.rgba(0, 0, 0, 0.12) : "transparent")
    exclusionMode: ExclusionMode.Ignore
    visible: !(Core.Session.overviewOpen && !root.launcherOpen)
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
    readonly property bool wallpaperOpen: root.host && wallpaperPicker.open
    readonly property bool themeOpen: root.host && themePicker.open
    readonly property bool stripOpen: root.wallpaperOpen || root.themeOpen
    readonly property bool showLaunchpad: root.launchpadOpen || (root.closingLaunchpad && root.intro > 0.01)
    readonly property bool showCard: root.launcherOpen && !root.showLaunchpad && !root.stripOpen
    readonly property bool onMain: Core.Session.isDesktopMonitor(Core.Session.monitorNameForScreen(root.screen))
    readonly property bool showLaunchpadDock: root.showLaunchpad && root.onMain

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
        visible: root.intro > 0.01
        clip: true

        readonly property string wall: Services.WallpaperService.current ? ("file://" + Services.WallpaperService.current) : ""

        // Solid wallpaper crop. Covers every pixel so windows never leak through.
        Image {
            anchors.fill: parent
            source: frost.wall
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            mipmap: true
            smooth: true
        }

        Item {
            id: wallSrc
            width: Math.max(1, Math.round(frost.width / 4))
            height: Math.max(1, Math.round(frost.height / 4))
            x: -width - 8
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true

            Image {
                anchors.fill: parent
                source: frost.wall
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                mipmap: true
                smooth: true
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: wallSrc
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 48
            blur: 1.0
            saturation: 0.85
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.08, 0.08, 0.10, 0.42)
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, 0.06)
        }
    }

    Modules.AppLauncher {
        id: appLauncher
        anchors.fill: parent
        anchors.leftMargin: root.showLaunchpadDock ? 96 : 0
        z: 2
        intro: root.intro
        opacity: root.showLaunchpad ? 1 : 0
        dockTarget: launchpadDock
    }

    DockBar {
        id: launchpadDock
        z: 4
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        intro: root.intro
        fadeWithIntro: false
        interactive: true
        visible: root.showLaunchpadDock
        enabled: root.showLaunchpadDock
        onLaunched: Core.PopupManager.close()
    }

    Item {
        z: 50
        visible: root.showLaunchpad && dragTile !== null
        width: 118
        height: 118
        x: appLauncher.dragX - width / 2
        y: appLauncher.dragY - height / 2
        scale: 1.16
        readonly property var dragTile: {
            if (appLauncher.folderDragging && appLauncher.folderDragApp)
                return {
                    "type": "app",
                    "entry": appLauncher.folderDragApp
                };
            if (appLauncher.dragging && appLauncher.dragFrom >= 0 && appLauncher.dragFrom < appLauncher.itemCount)
                return appLauncher.results[appLauncher.dragFrom];
            return null;
        }

        Rectangle {
            anchors.centerIn: parent
            width: 72
            height: 72
            radius: 18
            color: Qt.rgba(0, 0, 0, 0.28)
        }

        FolderGlyph {
            anchors.centerIn: parent
            width: 72
            height: 72
            visible: parent.dragTile && parent.dragTile.type === "folder"
            apps: parent.dragTile && parent.dragTile.apps ? parent.dragTile.apps : []
        }

        Image {
            anchors.centerIn: parent
            width: 96
            height: 96
            visible: parent.dragTile && parent.dragTile.type !== "folder"
            source: {
                const e = parent.dragTile;
                if (!e || e.type === "folder")
                    return "";
                return e.entry ? Services.AppsService.iconSource(e.entry) : "";
            }
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: true
        }
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

    Modules.WallpaperPicker {
        id: wallpaperPicker
        anchors.fill: parent
        z: 3
        hosted: root.host
    }

    Modules.ThemePicker {
        id: themePicker
        anchors.fill: parent
        z: 3
        hosted: root.host
    }
}
