import QtQuick

import "../core" as Core
import "../services" as Services

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: Core.Theme.moduleHeight

    function openPopup(id, item) {
        const p = item.mapToItem(null, item.width / 2, item.height);
        Core.PopupManager.hoverKeep = true;
        Core.PopupManager.open(id, p.x, p.y + Core.Theme.barMarginTop);
    }

    component StatIcon: Item {
        id: chip

        property string icon
        property string popupId
        property bool active: Core.PopupManager.isOpen(popupId)

        implicitWidth: 30
        implicitHeight: Core.Theme.moduleHeight

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.active ? Core.Theme.surfaceGlass : hover.hovered ? Core.Theme.surfaceGlassHover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 120
                    easing.type: Easing.OutQuint
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: chip.icon
            font.family: Core.Theme.iconFont
            font.pixelSize: Core.Theme.iconSize
            color: Core.Theme.foreground

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuint
                }
            }
        }

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) {
                    root.openPopup(chip.popupId, chip);
                    return;
                }
                Core.PopupManager.hoverKeep = false;
                Core.PopupManager.requestHoverClose(chip.popupId);
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPopup(chip.popupId, chip)
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        StatIcon {
            icon: "󰻠"
            popupId: "cpu"
        }

        StatIcon {
            icon: "󰍛"
            popupId: "memory"
        }
    }
}
