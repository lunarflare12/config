import QtQuick
import Quickshell
import Quickshell.Io
import "../components" as Components
import "../core" as Core

// Super+X. Same glass start-menu tiles as the app launcher.
Components.LauncherView {
    id: launcher

    launcherId: "power"
    promptIcon: Core.Icons.search
    placeholder: "Search power actions"
    startMenu: true
    cardWidth: 520
    forcedHeight: 320
    columns: 3
    cellHeight: 96
    contentMargins: 8
    vimNavigation: true

    readonly property var actions: [
        {
            "id": "shutdown",
            "title": "Shutdown",
            "icon": Core.Icons.power,
            "danger": true,
            "command": ["systemctl", "poweroff"]
        },
        {
            "id": "reboot",
            "title": "Reboot",
            "icon": Core.Icons.restart,
            "danger": false,
            "command": ["systemctl", "reboot"]
        },
        {
            "id": "bios",
            "title": "Reboot to BIOS",
            "icon": Core.Icons.computer,
            "danger": false,
            "command": ["systemctl", "reboot", "--firmware-setup"]
        },
        {
            "id": "logout",
            "title": "Logout",
            "icon": Core.Icons.logout,
            "danger": false,
            "command": ["loginctl", "terminate-session", Quickshell.env("XDG_SESSION_ID") || ""]
        },
        {
            "id": "lock",
            "title": "Lock",
            "icon": Core.Icons.lock,
            "danger": false,
            "command": ["qs", "ipc", "call", "lock", "lock"]
        },
        {
            "id": "sleep",
            "title": "Sleep",
            "icon": Core.Icons.sleep,
            "danger": false,
            "command": ["systemctl", "suspend"]
        }
    ]

    readonly property var results: {
        const q = launcher.query.trim().toLowerCase();
        if (q === "")
            return launcher.actions;
        return launcher.actions.filter(function (item) {
            return item.title.toLowerCase().indexOf(q) >= 0;
        });
    }

    itemCount: launcher.results.length

    onAccepted: {
        const item = launcher.results[launcher.selectedIndex];
        if (!item || !item.command || item.command.length === 0)
            return;
        launcher.dismiss();
        Quickshell.execDetached(item.command);
    }

    contentComponent: Component {
        Item {
            width: parent.width
            height: parent.height

            Text {
                id: pinnedLabel
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.top: parent.top
                anchors.topMargin: 6
                text: launcher.query.length === 0 ? "Power" : "Results"
                color: Core.Theme.foreground
                font.family: Core.Theme.fontFamily
                font.pixelSize: Core.Theme.fontSize
                font.weight: Font.DemiBold
            }

            GridView {
                id: grid

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pinnedLabel.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 8
                anchors.bottomMargin: 4

                model: launcher.results
                currentIndex: launcher.selectedIndex
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: false
                cellWidth: Math.floor(width / launcher.columns)
                cellHeight: launcher.cellHeight

                Text {
                    anchors.centerIn: parent
                    visible: launcher.results.length === 0
                    text: "No matching actions"
                    color: Core.Theme.foregroundFaint
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSize
                }

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool selected: cell.index === launcher.selectedIndex
                    z: cell.selected ? 2 : 0

                    Rectangle {
                        id: tile
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 12
                        color: "transparent"

                        Components.Tactile {
                            anchors.fill: parent
                            radius: 12
                            hovered: tileMouse.containsMouse
                            pressed: tileMouse.pressed
                            active: cell.selected
                            activeFill: cell.modelData.danger ? Qt.alpha(Core.Theme.danger, 0.18) : Qt.alpha(Core.Theme.accent, 0.16)
                        }

                        Text {
                            id: icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 14
                            text: cell.modelData.icon
                            color: cell.modelData.danger ? Core.Theme.danger : (cell.selected ? Core.Theme.accent : Core.Theme.foreground)
                            font.family: Core.Theme.iconFont
                            font.pixelSize: 28
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: icon.bottom
                            anchors.topMargin: 8
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignTop
                            text: cell.modelData.title
                            color: cell.selected ? Core.Theme.foreground : Core.Theme.foregroundMuted
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: Core.Theme.fontSizeSmall
                            font.weight: cell.selected ? Font.DemiBold : Font.Medium
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            launcher.selectedIndex = cell.index;
                            launcher.accepted();
                        }
                    }
                }
            }
        }
    }
}
