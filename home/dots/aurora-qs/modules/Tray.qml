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

    function isHidden(item) {
        const id = String(item.id || "").toLowerCase();
        const title = String(item.title || "").toLowerCase();
        const tooltip = String(item.tooltip || "").toLowerCase();

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

                    width: 17
                    height: 17

                    source: modelData.icon

                    fillMode: Image.PreserveAspectFit

                    smooth: true
                    mipmap: true
                }

                QsMenuAnchor {
                    id: trayMenu
                    menu: trayItem.modelData.menu
                    anchor.window: root.barWindow
                    anchor.item: trayItem
                    anchor.edges: Edges.Bottom | Edges.Left
                    anchor.gravity: Edges.Bottom | Edges.Right
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
    }
}
