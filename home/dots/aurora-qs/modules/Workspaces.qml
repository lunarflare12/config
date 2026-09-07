import QtQuick

import Quickshell
import Quickshell.Hyprland

import "../core" as Core

Item {
    id: root

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Core.Theme.moduleHeight

    readonly property int count: 10

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.count

            delegate: Item {
                id: cell

                required property int index

                readonly property int workspace: index + 1
                readonly property var hypr: {
                    const list = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : [];
                    for (let i = 0; i < list.length; i++) {
                        if (Number(list[i].id) === cell.workspace)
                            return list[i];
                    }
                    return null;
                }
                readonly property bool focused: Hyprland.focusedWorkspace && Number(Hyprland.focusedWorkspace.id) === cell.workspace
                readonly property bool occupied: {
                    if (!cell.hypr)
                        return false;
                    const ipc = cell.hypr.lastIpcObject || {};
                    const windows = ipc.windows;
                    if (typeof windows === "number")
                        return windows > 0;
                    const tops = cell.hypr.toplevels;
                    if (tops && tops.values)
                        return tops.values.length > 0;
                    return true;
                }

                width: 16
                height: 22

                Rectangle {
                    anchors.centerIn: parent
                    width: cell.focused ? 16 : 14
                    height: cell.focused ? 16 : 14
                    radius: height / 2
                    color: cell.focused ? Core.Theme.accent : (cell.occupied ? Core.Theme.surfaceActive : "transparent")
                    border.width: cell.focused ? 0 : 1
                    border.color: cell.occupied ? Core.Theme.borderFocus : Core.Theme.border

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                            easing.type: Easing.OutQuint
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.workspace === 10 ? "0" : String(cell.workspace)
                    color: cell.focused ? Core.Theme.accentForeground : (cell.occupied ? Core.Theme.text : Core.Theme.textMuted)
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeSmall
                    font.weight: cell.focused ? Font.DemiBold : Font.Medium
                    renderType: Text.QtRendering
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + cell.workspace)
                }
            }
        }
    }
}
