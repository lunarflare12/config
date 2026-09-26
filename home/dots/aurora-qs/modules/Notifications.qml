import QtQuick

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

    readonly property int toastWidth: 320

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
                    implicitHeight: note.implicitHeight
                    height: implicitHeight

                    transform: Translate {
                        x: wrapper.slide * 44
                    }

                    clip: true

                    Components.NotificationCard {
                        id: note
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        notification: wrapper.modelData
                        compact: true
                        progress: wrapper.progress
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

                    Text {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 10
                        anchors.topMargin: 8
                        text: Core.Icons.close
                        font.family: Core.Theme.iconFont
                        font.pixelSize: 14
                        color: Qt.rgba(1, 1, 1, 0.4)
                        renderType: Text.QtRendering
                        z: 2

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
