import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Wayland

import "../components" as Components
import "../core" as Core
import "../services" as Services

// Aurora Notifications — transient toast overlay

PanelWindow {
    id: root

    anchors.bottom: true
    anchors.right: true

    margins.bottom: 8
    margins.right: 16

    readonly property var toastModel: Services.NotificationServer.toastModel

    readonly property int toastWidth: 380

    readonly property int toastGutter: 4

    readonly property int toastSpacing: 8

    readonly property int maxHeight: 900

    implicitWidth: root.toastWidth + root.toastGutter * 2 + 14

    implicitHeight: root.maxHeight

    color: "transparent"

    WlrLayershell.namespace: "aurora-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    WlrLayershell.keyboardFocus: Services.NotificationServer.replyTarget !== null ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore

    visible: root.toastModel.count > 0 && !Core.PopupManager.isOpen("notifications")

    mask: Region {
        item: column
    }

    function toneOf(n, critical) {
        if (critical)
            return "error";
        let text = "";
        try {
            text = String(n.summary || "") + " " + String(n.body || "");
        } catch (e) {}
        text = text.toLowerCase();
        if (/fail|error|couldn't|could not|denied/.test(text))
            return "error";
        if (/warn|attention|review/.test(text))
            return "warning";
        if (/stop|start|restart|removed|resumed|paused|completed|saved|success|toggled/.test(text))
            return "success";
        return "info";
    }

    function palette(tone) {
        if (tone === "error")
            return {
                track: "#1A0C0E",
                fill: "#3B1518",
                ink: "#FFD5D8",
                muted: "#E7A8AE",
                icon: "#FF7F96"
            };
        if (tone === "warning")
            return {
                track: "#1A1608",
                fill: "#3A3010",
                ink: "#FFE7B0",
                muted: "#E0C47A",
                icon: "#FFD479"
            };
        if (tone === "success")
            return {
                track: "#0C1610",
                fill: "#16351F",
                ink: "#D8F3DE",
                muted: "#9FD4AB",
                icon: "#8FE3A5"
            };
        return {
            track: "#0C1420",
            fill: "#16304A",
            ink: "#D7E6FF",
            muted: "#9BB6DB",
            icon: "#8FB8FF"
        };
    }

    function toneIcon(tone) {
        if (tone === "error")
            return Core.Icons.closeCircle;
        if (tone === "warning")
            return Core.Icons.alertCircle;
        if (tone === "success")
            return Core.Icons.checkCircle;
        return Core.Icons.info;
    }

    Column {
        id: column

        anchors.bottom: parent.bottom
        anchors.right: parent.right

        width: root.toastWidth + root.toastGutter * 2

        spacing: root.toastSpacing

        move: Transition {
            NumberAnimation {
                property: "y"
                duration: 180
                easing.type: Easing.OutQuint
            }
        }

        Repeater {
            id: repeater

            model: root.toastModel

            delegate: Item {
                id: wrapper

                required property var nid

                readonly property var modelData: Services.NotificationServer.toastById(wrapper.nid)

                readonly property bool critical: Services.NotificationServer.isCritical(wrapper.modelData)

                readonly property int lifetime: Services.NotificationServer.lifetimeFor(wrapper.modelData)

                readonly property real cardHeight: Math.max(64, card.implicitHeight)

                readonly property bool replying: Services.NotificationServer.isReplying(wrapper.modelData)

                readonly property string tone: root.toneOf(wrapper.modelData, wrapper.critical)

                readonly property var colors: root.palette(wrapper.tone)

                property real progress: 1.0

                property bool dismissing: false

                property real slide: 1.0

                property real collapse: 1.0

                property real fade: 0.0

                width: root.toastWidth + root.toastGutter * 2

                height: Math.max(0, (wrapper.cardHeight + root.toastGutter * 2) * wrapper.collapse)

                opacity: wrapper.fade

                clip: true

                Component.onCompleted: {
                    enterAnim.start();
                    wrapper.syncDrain();
                }

                function syncDrain() {
                    if (wrapper.lifetime <= 0 || wrapper.dismissing)
                        return;
                    drainAnim.stop();
                    wrapper.progress = Services.NotificationServer.progressOf(wrapper.modelData);
                    drainAnim.from = wrapper.progress;
                    drainAnim.duration = Math.max(1, Services.NotificationServer.remainingOf(wrapper.modelData));
                    drainAnim.start();
                }

                function hide() {
                    if (wrapper.dismissing)
                        return;
                    wrapper.dismissing = true;
                    drainAnim.stop();
                    exitAnim.start();
                }

                function dismissFully() {
                    if (wrapper.dismissing)
                        return;
                    wrapper.dismissing = true;
                    drainAnim.stop();
                    Services.NotificationServer.dismiss(wrapper.modelData);
                }

                function activate() {
                    Services.NotificationServer.activate(wrapper.modelData, false);
                    if (wrapper.modelData)
                        wrapper.hide();
                }

                NumberAnimation {
                    id: drainAnim

                    target: wrapper
                    property: "progress"
                    from: 1.0
                    to: 0.0
                    duration: Math.max(1, Services.NotificationServer.remainingOf(wrapper.modelData))
                    easing.type: Easing.Linear
                    onFinished: {
                        if (!wrapper.dismissing && wrapper.lifetime > 0)
                            wrapper.hide();
                    }
                }

                ParallelAnimation {
                    id: enterAnim

                    NumberAnimation {
                        target: wrapper
                        property: "slide"
                        from: 1.0
                        to: 0.0
                        duration: 170
                        easing.type: Easing.OutQuint
                    }

                    NumberAnimation {
                        target: wrapper
                        property: "fade"
                        from: 0.0
                        to: 1.0
                        duration: 140
                        easing.type: Easing.OutQuint
                    }
                }

                SequentialAnimation {
                    id: exitAnim

                    ParallelAnimation {
                        NumberAnimation {
                            target: wrapper
                            property: "slide"
                            to: 1.0
                            duration: 150
                            easing.type: Easing.InQuint
                        }

                        NumberAnimation {
                            target: wrapper
                            property: "collapse"
                            to: 0.0
                            duration: 170
                            easing.type: Easing.InQuint
                        }

                        NumberAnimation {
                            target: wrapper
                            property: "fade"
                            to: 0.0
                            duration: 130
                            easing.type: Easing.InQuint
                        }
                    }

                    ScriptAction {
                        script: Services.NotificationServer.expireToast(wrapper.modelData)
                    }
                }

                Item {
                    id: card

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: root.toastGutter
                    anchors.rightMargin: root.toastGutter
                    anchors.topMargin: root.toastGutter
                    implicitHeight: Math.max(68, contentRow.implicitHeight + 24)
                    height: implicitHeight

                    transform: Translate {
                        x: wrapper.slide * 44
                    }

                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: wrapper.colors.track
                    }

                    Rectangle {
                        id: timerFill

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * Math.max(0, Math.min(1, wrapper.progress))
                        radius: 16
                        color: wrapper.colors.fill
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(wrapper.colors.icon, 0.22)
                    }

                    HoverHandler {
                        id: cardHover
                        onHoveredChanged: {
                            if (wrapper.lifetime <= 0 || wrapper.dismissing)
                                return;
                            if (cardHover.hovered) {
                                drainAnim.pause();
                                Services.NotificationServer.pauseToast(wrapper.modelData);
                            } else {
                                Services.NotificationServer.resumeToast(wrapper.modelData);
                                wrapper.syncDrain();
                            }
                        }
                    }

                    MouseArea {
                        id: toastMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                wrapper.dismissFully();
                                return;
                            }
                            if (mouse.button === Qt.MiddleButton) {
                                Services.NotificationServer.clearToasts();
                                return;
                            }
                            wrapper.activate();
                        }
                    }

                    RowLayout {
                        id: contentRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 1
                            text: root.toneIcon(wrapper.tone)
                            font.family: Core.Theme.iconFont
                            font.pixelSize: 18
                            color: wrapper.colors.icon
                            renderType: Text.QtRendering
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const n = wrapper.modelData;
                                    try {
                                        if (n.summary)
                                            return n.summary;
                                    } catch (e) {}
                                    return Services.NotificationServer.appLabel(wrapper.modelData);
                                }
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: wrapper.colors.ink
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                renderType: Text.QtRendering
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: {
                                    const n = wrapper.modelData;
                                    try {
                                        return n.body || "";
                                    } catch (e) {}
                                    return "";
                                }
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: 12
                                color: wrapper.colors.muted
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                                linkColor: wrapper.colors.icon
                                renderType: Text.QtRendering
                                onLinkActivated: function (link) {
                                    Quickshell.execDetached(["xdg-open", link]);
                                }
                            }

                            Components.NotificationActions {
                                Layout.fillWidth: true
                                Layout.topMargin: visible ? 6 : 0
                                notification: wrapper.modelData
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: Core.Icons.close
                            font.family: Core.Theme.iconFont
                            font.pixelSize: 14
                            color: Qt.alpha(wrapper.colors.ink, 0.45)
                            renderType: Text.QtRendering

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wrapper.dismissFully()
                            }
                        }
                    }
                }
            }
        }
    }
}
