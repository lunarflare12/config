import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property bool open: Core.Session.previewOpen
    readonly property bool host: Core.Session.monitorNameForScreen(root.screen) === Core.Session.focusedMonitorName()
    readonly property string path: Core.Session.previewPath
    readonly property string fileName: {
        const p = root.path;
        if (!p)
            return "";
        const i = p.lastIndexOf("/");
        return i >= 0 ? p.substring(i + 1) : p;
    }
    readonly property string lower: String(root.fileName).toLowerCase()
    readonly property bool isImage: !!root.lower.match(/\.(png|jpe?g|gif|webp|bmp|svg|avif|heic|jxl)$/)
    readonly property bool isText: !!root.lower.match(/\.(txt|md|log|csv|json|xml|yml|yaml|toml|ini|conf|nix|sh|bash|zsh|py|js|ts|rs|go|c|h|cpp|hpp|css|html|qml|lua|vim)$/) || root.lower === "readme"
    readonly property var desktopItem: Services.DesktopService.itemByPath(root.path)
    readonly property string imageUrl: {
        if (root.desktopItem && root.desktopItem.preview)
            return root.desktopItem.preview;
        if (root.isImage && root.path)
            return "file://" + root.path;
        return "";
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusiveZone: 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open

    WlrLayershell.namespace: "aurora-preview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open && root.host ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property Region emptyMask: Region {
        width: 0
        height: 0
    }

    mask: root.open ? null : root.emptyMask

    FileView {
        id: textFile
        path: root.open && root.host && root.isText && root.path ? root.path : ""
        blockLoading: false
        watchChanges: false
    }

    readonly property string textBody: {
        if (!textFile.loaded)
            return "";
        const raw = textFile.text();
        if (!raw)
            return "";
        return raw.length > 48000 ? raw.substring(0, 48000) + "\n…" : raw;
    }

    Item {
        id: catcher
        anchors.fill: parent
        focus: root.open && root.host
        Keys.onPressed: function (event) {
            if (!root.open || !root.host)
                return;
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space) {
                Core.Session.closePreview();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                Core.Session.previewStep(1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                Core.Session.previewStep(-1);
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: Core.Session.closePreview()
        }

        Rectangle {
            anchors.fill: parent
            visible: root.open
            color: Qt.rgba(0, 0, 0, 0.36)
        }

        Rectangle {
            id: card
            visible: root.open && root.host
            width: Math.round(Math.min(parent.width * 0.82, 1280))
            height: Math.round(Math.min(parent.height * 0.82, 860))
            anchors.centerIn: parent
            radius: Core.Theme.radiusMenu
            color: "transparent"
            border.width: Core.Theme.borderWidth
            border.color: Core.Theme.borderActive
            antialiasing: true
            clip: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onPressed: function (event) {
                    event.accepted = true;
                }
            }

            Glass {
                anchors.fill: parent
                radius: parent.radius
                strength: 1.0
            }

            Image {
                id: pic
                anchors.fill: parent
                anchors.margins: 18
                anchors.bottomMargin: label.height + 28
                visible: root.imageUrl.length > 0
                source: root.imageUrl
                fillMode: Image.PreserveAspectFit
                asynchronous: false
                cache: true
                smooth: true
                mipmap: true
                sourceSize.width: card.width
                sourceSize.height: card.height
            }

            Flickable {
                id: textPane
                anchors.fill: parent
                anchors.margins: 22
                anchors.bottomMargin: label.height + 28
                visible: root.isText && !pic.visible
                clip: true
                contentWidth: textCol.width
                contentHeight: textCol.height
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: textCol
                    width: textPane.width
                    text: root.textBody
                    wrapMode: Text.Wrap
                    font.family: Core.Theme.fontMono
                    font.pixelSize: Core.Theme.fontSize
                    color: Core.Theme.text
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: !pic.visible && !textPane.visible
                width: parent.width - 48

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 96
                    height: 96
                    source: Services.DesktopService.iconSource(root.desktopItem || {
                        "name": root.fileName,
                        "path": root.path,
                        "isDir": false
                    })
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.fileName
                    elide: Text.ElideMiddle
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeLarge
                    color: Core.Theme.foreground
                }
            }

            Text {
                id: label
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: {
                    const n = (Core.Session.previewPaths || []).length;
                    if (n > 1)
                        return (Core.Session.previewIndex + 1) + " / " + n + "  ·  " + root.fileName;
                    return root.fileName;
                }
                font.family: Core.Theme.fontFamily
                font.pixelSize: Core.Theme.fontSizeSmall
                color: Core.Theme.textSecondary
            }
        }
    }
}
