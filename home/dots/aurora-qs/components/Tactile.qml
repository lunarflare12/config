import QtQuick

import "../core" as Core

// Shared press language for every chip, row, and tile.
Item {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool active: false
    property bool feel: true
    property Item feelTarget: parent
    property real hoverScale: Core.Theme.hoverScale
    property real pressScale: Core.Theme.pressScale
    property real restScale: 1
    property color activeFill: Qt.rgba(1, 1, 1, 0.10)
    property real radius: parent && parent.height > 0 ? Math.min(parent.height, parent.width) / 2 : 12

    readonly property real targetScale: {
        if (!root.feel)
            return root.restScale;
        if (root.pressed)
            return root.pressScale;
        if (root.hovered)
            return root.hoverScale;
        if (root.active)
            return Math.max(root.restScale, 1);
        return root.restScale;
    }

    onTargetScaleChanged: root.kick()
    Component.onCompleted: root.kick()

    function kick() {
        if (!root.feelTarget)
            return;
        root.feelTarget.transformOrigin = Item.Center;
        if (!root.feel)
            return;
        scaleAnim.stop();
        scaleAnim.target = root.feelTarget;
        scaleAnim.to = root.targetScale;
        scaleAnim.duration = root.pressed ? 70 : 240;
        scaleAnim.easing.type = root.pressed ? Easing.OutCubic : Easing.OutBack;
        scaleAnim.easing.overshoot = 2.5;
        scaleAnim.start();
    }

    NumberAnimation {
        id: scaleAnim
        property: "scale"
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        color: {
            if (root.pressed)
                return Qt.rgba(0, 0, 0, 0.34);
            if (root.active)
                return root.activeFill;
            if (root.hovered)
                return Qt.rgba(1, 1, 1, 0.16);
            return "transparent";
        }
        border.width: root.pressed || root.hovered || root.active ? 1 : 0
        border.color: root.pressed ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.26)

        Behavior on color {
            ColorAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Math.max(6, parent.height * 0.42)
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, root.pressed ? 0.05 : root.hovered ? 0.22 : root.active ? 0.10 : 0)
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.5
            radius: parent.radius
            visible: root.pressed
            color: Qt.rgba(0, 0, 0, 0.32)
        }
    }
}
