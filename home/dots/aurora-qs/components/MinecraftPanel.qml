import QtQuick

import Quickshell

Item {
    id: panel

    property bool critical: false

    BorderImage {
        anchors.fill: parent
        source: "file://" + Quickshell.shellDir + "/assets/minecraft/toast.png"
        border.left: 6
        border.top: 6
        border.right: 6
        border.bottom: 6
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
        smooth: false
        antialiasing: false
        cache: true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        visible: panel.critical
        color: "transparent"
        border.width: 2
        border.color: "#AA0000"
    }
}
