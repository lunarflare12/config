import QtQuick

import "../core" as Core

// macOS-style hover: a quiet rounded wash, no gloss, no border, no bounce.
Item {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool active: false
    property bool feel: true
    property Item feelTarget: parent
    property real hoverScale: 1
    property real pressScale: 1
    property real restScale: 1
    property color activeFill: Qt.rgba(1, 1, 1, 0.10)
    property real radius: 6

    readonly property real targetScale: {
        if (!root.feel)
            return root.restScale;
        if (root.pressed)
            return root.pressScale;
        if (root.hovered)
            return root.hoverScale;
        return root.restScale;
    }

    onTargetScaleChanged: root.kick()
    Component.onCompleted: root.kick()

    function kick() {
        if (!root.feelTarget || !root.feel)
            return;
        root.feelTarget.transformOrigin = Item.Center;
        scaleAnim.stop();
        scaleAnim.target = root.feelTarget;
        scaleAnim.to = root.targetScale;
        scaleAnim.duration = root.pressed ? 80 : 140;
        scaleAnim.easing.type = Easing.OutCubic;
        scaleAnim.start();
    }

    NumberAnimation {
        id: scaleAnim
        property: "scale"
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: root.radius
        antialiasing: true
        color: {
            if (root.pressed)
                return Qt.rgba(1, 1, 1, 0.22);
            if (root.active)
                return root.activeFill;
            if (root.hovered)
                return Qt.rgba(1, 1, 1, 0.14);
            return "transparent";
        }

        Behavior on color {
            ColorAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }
    }
}
