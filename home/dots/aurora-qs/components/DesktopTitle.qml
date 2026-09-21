import QtQuick

import "../core" as Core

// Compact header matching PercentBoard: small demi-bold title, faint trailing.
Item {
    id: root

    property string title: ""
    property string trailing: ""
    property url iconSource: ""
    property string iconName: ""
    property color iconColor: Core.Theme.foreground

    implicitHeight: 18
    height: implicitHeight

    Image {
        id: pix

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? 16 : 0
        height: 16
        visible: root.iconSource !== "" && status === Image.Ready
        source: root.iconSource
        sourceSize.width: 48
        sourceSize.height: 48
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
    }

    MetricIcon {
        id: glyph

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? 16 : 0
        height: 16
        visible: !pix.visible && root.iconName !== ""
        name: root.iconName
        color: root.iconColor
    }

    Text {
        id: titleLabel

        anchors.left: pix.visible ? pix.right : (glyph.visible ? glyph.right : parent.left)
        anchors.leftMargin: pix.visible || glyph.visible ? 6 : 0
        anchors.right: trail.visible ? trail.left : parent.right
        anchors.rightMargin: trail.visible ? 8 : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        elide: Text.ElideRight
        color: Core.Theme.foreground
        font.family: Core.Theme.fontFamily
        font.pixelSize: Core.Theme.fontSizeSmall
        font.weight: Font.DemiBold
        renderType: Text.QtRendering
    }

    Text {
        id: trail

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.trailing !== ""
        text: root.trailing
        color: Core.Theme.foregroundFaint
        font.family: Core.Theme.fontFamily
        font.pixelSize: Core.Theme.fontSizeSmall
        renderType: Text.NativeRendering
    }
}
