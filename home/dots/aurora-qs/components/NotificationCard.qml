import QtQuick

import "../core" as Core
import "../services" as Services

// Mako/dunst-style card — unixporn default, not Windows pills.
Item {
    id: root

    property var notification: null
    property bool showAge: false
    property real progress: -1
    property bool compact: false

    readonly property bool critical: Services.NotificationServer.isCritical(root.notification)
    readonly property string appName: Services.NotificationServer.appLabel(root.notification)
    readonly property string iconSource: Services.NotificationServer.iconFor(root.notification)
    readonly property string summary: {
        try {
            return root.notification && root.notification.summary ? String(root.notification.summary) : "";
        } catch (e) {
            return "";
        }
    }
    readonly property string body: {
        try {
            return root.notification && root.notification.body ? String(root.notification.body) : "";
        } catch (e) {
            return "";
        }
    }

    implicitHeight: Math.max(52, Math.max(iconBox.height, textCol.implicitHeight) + 16)

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.alpha(Core.Theme.background, 1)
        border.width: 2
        border.color: root.critical ? Core.Theme.danger : Core.Theme.border
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 2
        width: 3
        radius: 1
        color: root.critical ? Core.Theme.danger : Core.Theme.accent
    }

    Item {
        id: iconBox
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        width: 32
        height: 32

        Image {
            id: appIcon
            anchors.fill: parent
            source: root.iconSource
            visible: root.iconSource !== "" && status === Image.Ready
            asynchronous: true
            cache: true
            smooth: true
            fillMode: Image.PreserveAspectFit
        }

        Text {
            anchors.centerIn: parent
            visible: !appIcon.visible
            text: Core.Icons.forApp(root.appName)
            font.family: Core.Theme.iconFont
            font.pixelSize: 18
            color: Core.Theme.foreground
            renderType: Text.QtRendering
        }
    }

    Column {
        id: textCol
        anchors.left: iconBox.right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 1

        Text {
            width: parent.width
            visible: root.summary !== ""
            text: root.summary
            elide: Text.ElideRight
            font.family: Core.Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Core.Theme.foreground
            renderType: Text.QtRendering
        }

        Text {
            width: parent.width
            visible: root.body !== ""
            text: root.body
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: Core.Theme.fontFamily
            font.pixelSize: 11
            color: Core.Theme.foregroundMuted
            renderType: Text.QtRendering
        }

        NotificationActions {
            width: parent.width
            chipHeight: 20
            notification: root.notification
        }
    }
}