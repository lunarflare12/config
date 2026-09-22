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

    readonly property var launchers: [appLauncher, appearancePicker, clipboardView, emojiPicker, powerMenu]

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
    readonly property bool wallpaperOpen: root.host && appearancePicker.open && appearancePicker.mode === "wallpaper"
    readonly property bool themeOpen: root.host && appearancePicker.open && appearancePicker.mode === "theme"
    readonly property bool cursorOpen: root.host && appearancePicker.open && appearancePicker.mode === "cursor"
    readonly property bool stripOpen: root.host && appearancePicker.open
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

        readonly property string wallPath: {
            const cur = Services.WallpaperService.current;
            if (cur && cur.length)
                return cur;
            const list = Services.WallpaperService.wallpapers;
            if (list && list.length && list[0].path)
                return list[0].path;
            return "";
        }
        readonly property string wall: frost.wallPath.length ? ("file://" + frost.wallPath) : ""

        Rectangle {
            anchors.fill: parent
            color: "#1a1a1e"
        }

        Image {
            id: wallImage
            anchors.fill: parent
            source: frost.wall
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
            mipmap: true
            smooth: true
            visible: status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.04, 0.04, 0.06, wallImage.status === Image.Ready ? 0.28 : 0)
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

    Modules.AppearancePicker {
        id: appearancePicker
        anchors.fill: parent
        z: 3
        hosted: root.host
    }
}
