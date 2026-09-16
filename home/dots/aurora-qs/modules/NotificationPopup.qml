import QtQuick

import Quickshell
import Quickshell.Io

import "../core" as Core
import "../services" as Services
import "../components" as Components

// NotificationPopup

Components.PopupSurface {
    id: popup

    popupId: "notifications"

    cardWidth: 360
    maxCardHeight: 480

    readonly property var list: Services.NotificationServer.notifications

    readonly property int count: (popup.list && popup.list.values) ? popup.list.values.length : 0

    readonly property bool dnd: Core.PopupManager.dnd

    function setDnd(value) {
        Core.PopupManager.dnd = value;
    }

    function dismiss(n) {
        if (!n)
            return;
        if (typeof n.dismiss === "function")
            n.dismiss();
        else if (typeof n.expire === "function")
            n.expire();
    }

    function clearAll() {
        if (!popup.list || !popup.list.values)
            return;
        const snapshot = popup.list.values.slice();

        for (let i = 0; i < snapshot.length; i++)
            popup.dismiss(snapshot[i]);
    }

    // Invoking an action closes the notification for us unless the sender marked
    // it resident. This used to call dismiss() afterwards, which meant a second
    // close on an already-destroyed object and a "Cannot close destroyed
    // notification" critical from Quickshell on every single action press.
    function invoke(n, action) {
        Services.NotificationServer.invokeAction(n, action);
    }

    function copyText(text) {
        if (!text || text === "")
            return;
        try {
            Quickshell.clipboardText = text;
        } catch (e) {
            copyProc.command = ["sh", "-c", "printf %s " + JSON.stringify(text) + " | wl-copy"];
            copyProc.running = true;
        }
    }

    // Both of these live on the service so the toast overlay and this panel
    // cannot disagree about what a notification is called or how urgent it is.
    function appLabel(n) {
        return Services.NotificationServer.appLabel(n);
    }

    function isCritical(n) {
        return Services.NotificationServer.isCritical(n);
    }

    Process {
        id: copyProc

        running: false
    }

    // Content

    contentComponent: Component {

        Column {
            id: body

            spacing: Core.Theme.spacing

            // Header

            Components.PopupHeader {
                width: body.width

                title: "Notifications"

                subtitle: popup.dnd ? "Do not disturb" : popup.count === 0 ? "All caught up" : popup.count === 1 ? "1 notification" : popup.count + " notifications"

                showToggle: true

                // The toggle drives do-not-disturb; on means "allowed".
                toggled: !popup.dnd

                onToggleRequested: popup.setDnd(!popup.dnd)

                actions: [
                    {
                        icon: "\udb80\uddb4",
                        tooltip: "Clear all",
                        action: function () {
                            popup.clearAll();
                        }
                    }
                ]
            }

            // Do-not-disturb banner

            Rectangle {
                width: body.width

                height: popup.dnd ? 32 : 0

                visible: height > 1

                clip: true

                radius: Core.Theme.radiusRow

                color: Qt.alpha(Core.Theme.warning, 0.13)

                Behavior on height {
                    NumberAnimation {
                        duration: Core.Theme.durBase
                        easing.type: Easing.OutQuint
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    text: Core.Icons.bellOff + "  New alerts are being silenced"

                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeSmall

                    color: Core.Theme.warning
                }
            }

            // The list

            Item {
                id: listBox

                readonly property int maxListHeight: 330

                width: body.width

                height: Math.min(list.contentHeight, listBox.maxListHeight)

                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Core.Theme.durBase
                        easing.type: Easing.OutQuint
                    }
                }

                ListView {
                    id: list

                    anchors.fill: parent

                    spacing: 4

                    clip: true

                    boundsBehavior: Flickable.StopAtBounds

                    model: popup.list

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 160
                            easing.type: Easing.OutQuint
                        }
                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: 160
                            easing.type: Easing.InQuint
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: 170
                            easing.type: Easing.OutQuint
                        }
                    }

                    addDisplaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: 170
                            easing.type: Easing.OutQuint
                        }
                    }

                    removeDisplaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: 160
                            easing.type: Easing.OutQuint
                        }
                    }

                    delegate: Item {
                        id: noteRow

                        required property var modelData

                        width: list.width
                        implicitHeight: Math.max(noteLayout.implicitHeight, 40) + 18
                        height: implicitHeight

                        Components.MinecraftPanel {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.topMargin: 3
                            anchors.bottomMargin: 3
                            critical: popup.isCritical(noteRow.modelData)
                        }

                        Item {
                            id: iconBox
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            width: 40
                            height: 40

                            Image {
                                anchors.fill: parent
                                source: "file://" + Quickshell.shellDir + "/assets/minecraft/slot.png"
                                smooth: false
                                antialiasing: false
                                fillMode: Image.Stretch
                            }

                            readonly property string resolvedIcon: Services.NotificationServer.iconFor(noteRow.modelData)

                            Image {
                                id: noteIcon
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                source: iconBox.resolvedIcon
                                visible: iconBox.resolvedIcon !== "" && status === Image.Ready
                                asynchronous: true
                                cache: true
                                smooth: false
                                mipmap: false
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !noteIcon.visible
                                text: Core.Icons.forApp(popup.appLabel(noteRow.modelData))
                                font.family: Core.Theme.iconFont
                                font.pixelSize: 22
                                color: "#FFFF55"
                                renderType: Text.NativeRendering
                            }
                        }

                        Column {
                            id: noteLayout

                            anchors.left: iconBox.right
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 34

                            spacing: 2

                            Item {
                                width: parent.width
                                height: appText.implicitHeight

                                Text {
                                    id: appText
                                    anchors.left: parent.left
                                    anchors.right: ageText.left
                                    anchors.rightMargin: 6
                                    text: popup.appLabel(noteRow.modelData)
                                    elide: Text.ElideRight
                                    font.family: Core.Theme.fontPixel
                                    font.pixelSize: 14
                                    font.kerning: false
                                    color: "#AAAAAA"
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    id: ageText
                                    anchors.right: parent.right
                                    anchors.baseline: appText.baseline
                                    text: {
                                        const tick = Services.NotificationServer.ageTick;
                                        return Services.NotificationServer.ageText(noteRow.modelData);
                                    }
                                    font.family: Core.Theme.fontPixel
                                    font.pixelSize: 14
                                    font.kerning: false
                                    color: "#555555"
                                    renderType: Text.NativeRendering
                                }
                            }

                            Text {
                                width: parent.width
                                text: noteRow.modelData.summary ? noteRow.modelData.summary : ""
                                visible: text !== ""
                                elide: Text.ElideRight
                                font.family: Core.Theme.fontPixel
                                font.pixelSize: 16
                                font.kerning: false
                                color: popup.isCritical(noteRow.modelData) ? "#FF5555" : "#FFFF55"
                                renderType: Text.NativeRendering
                            }

                            Text {
                                width: parent.width
                                text: noteRow.modelData.body ? noteRow.modelData.body : ""
                                visible: text !== ""
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                                linkColor: "#55FFFF"
                                onLinkActivated: function (link) {
                                    Quickshell.execDetached(["xdg-open", link]);
                                }
                                font.family: Core.Theme.fontPixel
                                font.pixelSize: 16
                                font.kerning: false
                                color: "#FFFFFF"
                                renderType: Text.NativeRendering
                            }

                            Components.NotificationActions {
                                width: parent.width
                                chipHeight: 22
                                notification: noteRow.modelData
                            }
                        }

                        // Per-notification close button
                        Rectangle {
                            id: closeBtn

                            anchors.right: parent.right
                            anchors.top: parent.top

                            anchors.rightMargin: 6
                            anchors.topMargin: 6

                            width: 22
                            height: 22

                            radius: 11

                            color: closeMouse.containsMouse ? Core.Theme.surfaceHover : "transparent"

                            opacity: noteMouse.containsMouse || closeMouse.containsMouse ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.OutQuint
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                text: Core.Icons.close

                                font.family: Core.Theme.iconFont
                                font.pixelSize: Core.Theme.iconSizeSmall

                                color: Core.Theme.foregroundMuted
                            }

                            MouseArea {
                                id: closeMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: popup.dismiss(noteRow.modelData)
                            }
                        }

                        MouseArea {
                            id: noteMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape: Qt.PointingHandCursor

                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            z: -1

                            onClicked: function (event) {
                                if (event.button === Qt.LeftButton) {
                                    popup.dismiss(noteRow.modelData);
                                    return;
                                }

                                // Capture values now — the delegate is recycled and modelData can change before the menu action runs.
                                const note = noteRow.modelData;

                                const summary = note.summary ? String(note.summary) : "";

                                const bodyText = note.body ? String(note.body) : "";

                                const app = popup.appLabel(note);

                                const point = noteRow.mapToItem(null, event.x, event.y);

                                popup.openMenu(point.x, point.y, [
                                    {
                                        icon: Core.Icons.close,
                                        label: "Dismiss",
                                        action: function () {
                                            popup.dismiss(note);
                                        }
                                    },
                                    {
                                        icon: "\udb81\udcd6",
                                        label: "Copy text",
                                        action: function () {
                                            popup.copyText(summary + (bodyText !== "" ? "\n" + bodyText : ""));
                                        }
                                    },
                                    {
                                        icon: "\udb80\udd7c",
                                        label: "Copy app name",
                                        action: function () {
                                            popup.copyText(app);
                                        }
                                    },
                                    {
                                        separator: true
                                    },
                                    {
                                        icon: Core.Icons.bellOff,
                                        label: popup.dnd ? "Turn off do not disturb" : "Turn on do not disturb",
                                        action: function () {
                                            popup.setDnd(!popup.dnd);
                                        }
                                    },
                                    {
                                        icon: "\udb80\uddb4",
                                        label: "Clear all",
                                        danger: true,
                                        action: function () {
                                            popup.clearAll();
                                        }
                                    }
                                ]);
                            }
                        }
                    }
                }
            }

            // Empty state

            Item {
                width: body.width

                height: popup.count === 0 ? 96 : 0

                visible: height > 1

                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Core.Theme.durBase
                        easing.type: Easing.OutQuint
                    }
                }

                Column {
                    anchors.centerIn: parent

                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter

                        text: "\udb80\udc9c"

                        font.family: Core.Theme.iconFont
                        font.pixelSize: Core.Theme.iconSizeMedium

                        color: Core.Theme.foregroundFaint
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter

                        text: "Nothing to catch up on"

                        font.family: Core.Theme.fontFamily
                        font.pixelSize: Core.Theme.fontSizeSmall

                        color: Core.Theme.foregroundMuted
                    }
                }
            }
        }
    }
}
