import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Services.SystemTray

import "../core" as Core
import "../components" as Components

Item {
    id: root

    property var barWindow: null
    property bool menuOpen: false

    implicitWidth: trayRow.implicitWidth
    implicitHeight: Core.Theme.moduleHeight

    // Hidden system tray applications

    function iconFor(item) {
        const id = String(item.id || "").toLowerCase();
        const title = String(item.title || "").toLowerCase();
        const icon = String(item.icon || "");
        if (id === "steam" || title === "steam" || icon.indexOf("steam_tray") >= 0)
            return Qt.resolvedUrl("../assets/bar/steam.png");
        if (id.indexOf("spotify") >= 0 || title.indexOf("spotify") >= 0 || icon.indexOf("spotify") >= 0)
            return Qt.resolvedUrl("../assets/bar/spotify.svg");
        return icon;
    }

    function trayBlob(item) {
        if (!item)
            return "";
        return String((item.id || "") + " " + (item.title || "") + " " + (item.tooltip || "") + " " + (item.icon || "")).toLowerCase();
    }

    function hasSpotifySni() {
        const model = SystemTray.items;
        const items = model && model.values ? model.values : [];
        for (let i = 0; i < items.length; i++) {
            if (root.trayBlob(items[i]).indexOf("spotify") >= 0)
                return true;
        }
        return false;
    }

    readonly property int clientsWatch: Core.Session.clientsTick
    readonly property bool spotifyRunning: {
        const _ = root.clientsWatch;
        const classes = Core.Session.openClasses || [];
        for (let i = 0; i < classes.length; i++) {
            const c = String(classes[i] || "");
            if (c === "spotify" || c === "spotify-client")
                return true;
        }
        const clients = Core.Session.openClients || [];
        for (let j = 0; j < clients.length; j++) {
            const blob = String((clients[j].class || "") + " " + (clients[j].title || "")).toLowerCase();
            if (blob.indexOf("spotify") >= 0)
                return true;
        }
        return false;
    }
    readonly property bool showSpotify: {
        const _ = SystemTray.items;
        return root.spotifyRunning && !root.hasSpotifySni();
    }

    function isHidden(item) {
        const id = String(item.id || "").toLowerCase();
        const title = String(item.title || "").toLowerCase();
        const tooltip = String(item.tooltip || "").toLowerCase();

        if (id.includes("chrome_status_icon") || title.includes("chrome_status_icon"))
            return true;
        return (id.includes("nm-applet") || id.includes("networkmanager") || id.includes("blueman") || title.includes("networkmanager") || title.includes("blueman") || tooltip.includes("networkmanager") || tooltip.includes("blueman"));
    }

    RowLayout {
        id: trayRow

        anchors.centerIn: parent

        spacing: 2

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayItem

                required property var modelData

                // Hide NetworkManager and Blueman from the visual tray while keeping their processes alive.
                visible: !root.isHidden(modelData)

                implicitWidth: visible ? 26 : 0

                implicitHeight: Core.Theme.moduleHeight

                Components.Tactile {
                    anchors.fill: parent
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                }

                Image {
                    anchors.centerIn: parent

                    width: Core.Theme.iconSize
                    height: Core.Theme.iconSize

                    source: root.iconFor(modelData)
                    sourceSize.width: Core.Theme.iconSize
                    sourceSize.height: Core.Theme.iconSize

                    fillMode: Image.PreserveAspectFit

                    smooth: false
                    mipmap: false
                }

                QsMenuAnchor {
                    id: trayMenu
                    menu: trayItem.modelData.menu
                    anchor.window: root.barWindow
                    anchor.item: trayItem
                    anchor.edges: Edges.Bottom | Edges.Left
                    anchor.gravity: Edges.Top | Edges.Left
                    onOpened: root.menuOpen = true
                    onClosed: root.menuOpen = false
                    onVisibleChanged: root.menuOpen = trayMenu.visible
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: function (event) {
                        if (event.button === Qt.RightButton) {
                            if (trayItem.modelData.hasMenu) {
                                Qt.callLater(function () {
                                    trayMenu.open();
                                });
                            }
                            return;
                        }

                        if (event.button === Qt.LeftButton) {
                            const id = String(trayItem.modelData.id || "").toLowerCase();
                            const title = String(trayItem.modelData.title || "").toLowerCase();
                            const icon = String(trayItem.modelData.icon || "");
                            const steam = id === "steam" || title === "steam" || icon.indexOf("steam_tray") >= 0;
                            if (steam && Core.Session.focusClass("steam"))
                                return;
                            if ((id.indexOf("spotify") >= 0 || title.indexOf("spotify") >= 0) && Core.Session.focusClass("spotify"))
                                return;
                            if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu) {
                                Qt.callLater(function () {
                                    trayMenu.open();
                                });
                                return;
                            }
                            trayItem.modelData.activate();
                            return;
                        }

                        if (event.button === Qt.MiddleButton) {
                            trayItem.modelData.secondaryActivate();
                        }
                    }
                }
            }
        }

        // Spotify runs in an isolated box and never registers StatusNotifier.
        Item {
            visible: root.showSpotify
            implicitWidth: visible ? 26 : 0
            implicitHeight: Core.Theme.moduleHeight

            Components.Tactile {
                anchors.fill: parent
                hovered: spotifyMouse.containsMouse
                pressed: spotifyMouse.pressed
            }

            Image {
                anchors.centerIn: parent
                width: Core.Theme.iconSize
                height: Core.Theme.iconSize
                source: Qt.resolvedUrl("../assets/bar/spotify.svg")
                sourceSize.width: Core.Theme.iconSize
                sourceSize.height: Core.Theme.iconSize
                fillMode: Image.PreserveAspectFit
                smooth: false
                mipmap: false
            }

            MouseArea {
                id: spotifyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: Core.Session.focusClass("spotify")
            }
        }
    }
}
