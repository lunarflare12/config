import QtQuick

import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../modules" as Modules

// Launchers used to live inside the bar layer, which forced a ~666px-tall
// surface even while closed. They are a separate overlay mapped only when open.
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.launcherOpen

    WlrLayershell.namespace: "aurora-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var launchers: [appLauncher, wallpaperPicker, themePicker, clipboardView, emojiPicker]

    readonly property var activeLauncher: {
        const list = root.launchers;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].open)
                return list[i];
        }
        return null;
    }

    readonly property bool launcherOpen: root.activeLauncher !== null

    MouseArea {
        anchors.fill: parent
        enabled: root.launcherOpen
        acceptedButtons: Qt.LeftButton
        onClicked: Core.PopupManager.close()
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: Core.Theme.barHeight + Core.Theme.popupGap + 8

        width: root.activeLauncher ? root.activeLauncher.cardWidth : 460
        height: root.activeLauncher ? root.activeLauncher.viewHeight : 110
        radius: Core.Theme.radiusLarge
        color: "transparent"
        antialiasing: true
        clip: true
        visible: root.launcherOpen

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
        }

        Item {
            anchors.fill: parent

            Modules.AppLauncher {
                id: appLauncher
                anchors.fill: parent
            }

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
        }
    }
}
