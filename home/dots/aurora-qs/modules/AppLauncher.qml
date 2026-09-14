import QtQuick
import Quickshell
import Quickshell.Io
import "../components" as Components
import "../core" as Core
import "../services" as Services

// Windows 11-style start menu: app tiles, user, power off.
Components.LauncherView {
    id: launcher

    launcherId: "launcher"
    promptIcon: Core.Icons.search
    placeholder: "Search for apps, settings, and documents"

    startMenu: true
    cardWidth: 660
    forcedHeight: 620
    footerHeight: 56
    columns: 6
    cellHeight: 96
    contentMargins: 8
    vimNavigation: true
    footerComponent: startFooter

    readonly property string userName: {
        const u = Quickshell.env("USER") || "user";
        if (!u.length)
            return "user";
        return u.charAt(0).toUpperCase() + u.slice(1);
    }

    readonly property var results: Services.AppsService.search(launcher.query)
    itemCount: launcher.results.length

    onAccepted: {
        const entry = launcher.results[launcher.selectedIndex];
        if (!entry)
            return;
        launcher.dismiss();
        Services.AppsService.launch(entry);
    }

    function powerOff() {
        launcher.dismiss();
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcher.toggle();
        }

        function open(): void {
            launcher.show();
        }

        function close(): void {
            launcher.dismiss();
        }
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
                text: launcher.query.length === 0 ? "Pinned" : "Results"
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
                cacheBuffer: 4000
                reuseItems: true
                interactive: false

                cellWidth: Math.floor(width / launcher.columns)
                cellHeight: launcher.cellHeight

                onCurrentIndexChanged: grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)

                Text {
                    anchors.centerIn: parent
                    visible: launcher.results.length === 0
                    text: "No matching applications"
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
                        }

                        Image {
                            id: icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            width: 40
                            height: 40
                            asynchronous: true
                            cache: true
                            sourceSize.width: 64
                            sourceSize.height: 64
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            source: Services.AppsService.iconSource(cell.modelData)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: icon.bottom
                            anchors.topMargin: 6
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            anchors.leftMargin: 2
                            anchors.rightMargin: 2
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignTop
                            text: Services.AppsService.displayName(cell.modelData)
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

    Component {
        id: startFooter

        Item {
            width: parent ? parent.width : 660
            height: 56

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Core.Theme.separator
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Core.Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: launcher.userName.charAt(0)
                        color: Core.Theme.background
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: Core.Theme.fontSize
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: launcher.userName
                    color: Core.Theme.foreground
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSize
                    font.weight: Font.Medium
                }
            }

            Rectangle {
                id: powerBtn
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: 8
                color: "transparent"

                Components.Tactile {
                    anchors.fill: parent
                    radius: 8
                    hovered: powerMouse.containsMouse
                    pressed: powerMouse.pressed
                    activeFill: Qt.alpha(Core.Theme.danger, 0.18)
                    active: powerMouse.containsMouse
                }

                Text {
                    anchors.centerIn: parent
                    text: Core.Icons.power
                    color: powerMouse.containsMouse ? Core.Theme.danger : Core.Theme.foregroundMuted
                    font.family: Core.Theme.iconFont
                    font.pixelSize: Core.Theme.iconSize
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcher.powerOff()
                }
            }
        }
    }
}
