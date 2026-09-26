import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core

PanelWindow {
    id: root

    property string popupId: ""
    property int cardWidth: Core.Theme.popupWidth
    property int maxCardHeight: Core.Theme.popupMaxHeight
    property Component contentComponent: null

    readonly property bool open: Core.PopupManager.isOpen(root.popupId)
    readonly property bool menuOpen: menuLayer.active

    signal didOpen
    signal didClose

    function openMenu(x, y, items) {
        menuLayer.show(x, y, items);
    }

    function closeMenu() {
        menuLayer.close();
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: root.sheetHeight + 48

    color: "transparent"

    exclusionMode: ExclusionMode.Ignore

    visible: root.windowVisible
    screen: Core.PopupManager.anchorScreen || (Quickshell.screens.length ? Quickshell.screens[0] : null)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-popup"

    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool windowVisible: false
    property bool sheetOpen: false

    property Region noInput: Region {
        width: 0
        height: 0
    }

    mask: root.windowVisible ? null : root.noInput

    function publishExtent() {
        if (root.fromCenter)
            return;
        if (root.windowVisible) {
            Core.PopupManager.rightSheetExtent = card.y + card.height;
            Core.PopupManager.rightSheetWidth = card.width;
        } else if (Core.PopupManager.current === "" || Core.PopupManager.current === root.popupId) {
            Core.PopupManager.rightSheetExtent = 0;
            Core.PopupManager.rightSheetWidth = 0;
        }
    }

    onOpenChanged: {
        if (root.open) {
            closeTimer.stop();
            root.windowVisible = true;
            root.didOpen();
            root.publishExtent();
            Qt.callLater(function () {
                if (root.open) {
                    root.sheetOpen = true;
                    escapeSink.forceActiveFocus();
                }
            });
        } else {
            root.sheetOpen = false;
            menuLayer.close();
            root.didClose();
            root.publishExtent();
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: Core.Theme.animDuration + 20
        onTriggered: {
            if (!root.open) {
                root.windowVisible = false;
                root.publishExtent();
            }
        }
    }

    readonly property bool fromCenter: root.popupId === "calendar"
    readonly property bool hangRight: !root.fromCenter
    readonly property int fw: Core.Theme.notchRadius
    readonly property real naturalHeight: contentHost.implicitHeight + Core.Theme.padding * 2
    readonly property real targetHeight: Math.min(root.naturalHeight, root.maxCardHeight)
    readonly property int sheetWidth: root.fromCenter ? Core.Theme.centerSheetWidth : root.cardWidth
    readonly property int sheetBody: root.targetHeight + 20
    readonly property int sheetHeight: root.hangRight ? Core.Theme.notchHeight + root.sheetBody : Core.Theme.notchHeight + root.targetHeight + 24
    readonly property int closedWidth: root.fromCenter ? Core.Theme.cNotchMinWidth : Core.Theme.rNotchMinWidth
    readonly property int liveWidth: {
        if (root.fromCenter)
            return root.sheetOpen ? root.sheetWidth : root.closedWidth;
        const notch = Core.PopupManager.rightNotchWidth;
        return notch > 1 ? notch : root.sheetWidth;
    }

    MouseArea {
        anchors.fill: parent

        enabled: root.open

        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: {
            if (menuLayer.active) {
                menuLayer.close();
                return;
            }

            Core.PopupManager.close();
        }
    }

    Item {
        id: escapeSink
        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: {
            if (menuLayer.active)
                menuLayer.close();
            else
                Core.PopupManager.dismissAll();
        }
    }

    Item {
        id: card
        x: root.fromCenter ? Math.round((parent.width - width) / 2) : parent.width - width
        y: root.hangRight ? Core.Theme.notchHeight - 1 : 0
        clip: true
        width: root.liveWidth
        height: root.sheetOpen ? (root.hangRight ? root.sheetBody : root.sheetHeight) : 0

        Behavior on width {
            enabled: root.fromCenter
            NumberAnimation {
                duration: Core.Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Core.Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        onHeightChanged: root.publishExtent()
        onWidthChanged: root.publishExtent()

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupShape {
            anchors.fill: parent
            attachedEdge: root.fromCenter ? "notch-center" : "notch-right"
            fill: Core.Theme.background
            radius: Core.Theme.frameRadius
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Core.Theme.notchHeight
            enabled: root.sheetOpen && !root.hangRight
            cursorShape: Qt.PointingHandCursor
            onClicked: Core.PopupManager.close()
        }

        Item {
            id: contentHost
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: root.hangRight ? 14 : Core.Theme.notchHeight + 8
            anchors.bottomMargin: 16
            implicitHeight: contentLoader.item ? (contentLoader.item as Item).implicitHeight : 0
            clip: true

            readonly property real span: root.hangRight ? root.sheetBody : root.sheetHeight
            readonly property real grown: contentHost.span > 1 ? Math.max(0, Math.min(1, card.height / contentHost.span)) : 0
            opacity: root.sheetOpen ? Math.max(0, Math.min(1, (contentHost.grown - 0.18) / 0.82)) : 0

            Loader {
                id: contentLoader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                active: true
                sourceComponent: root.contentComponent

                onWidthChanged: contentLoader.pinWidth()
                onLoaded: contentLoader.pinWidth()

                function pinWidth() {
                    const child = contentLoader.item as Item;
                    if (child && child.width !== contentLoader.width)
                        child.width = contentLoader.width;
                }
            }
        }
    }

    Item {
        id: menuLayer

        anchors.fill: parent

        z: 999

        property bool active: false
        property var items: []

        property real targetX: 0
        property real targetY: 0

        function show(x, y, list) {
            menuLayer.items = list;
            menuLayer.targetX = x;
            menuLayer.targetY = y;
            menuLayer.active = true;

            Core.PopupManager.contextMenuOpen = true;
        }

        function close() {
            menuLayer.active = false;
            Core.PopupManager.contextMenuOpen = false;
        }

        visible: menuLayer.active || menuBox.opacity > 0.01

        Rectangle {
            id: menuBox

            width: 200

            height: menuColumn.implicitHeight + 10

            x: Math.round(Math.max(6, Math.min(menuLayer.width - width - 6, menuLayer.targetX)))

            y: Math.round(Math.max(6, Math.min(menuLayer.height - height - 6, menuLayer.targetY)))

            radius: Core.Theme.radiusMenu

            color: "transparent"

            border.width: Core.Theme.borderWidth
            border.color: Core.Theme.borderActive

            antialiasing: true

            // The context menu is drawn inside this window rather than being its
            // own surface, so Hyprland does not animate it. A plain fade, with no
            // scale, so it does not pop toward the viewer either.
            opacity: menuLayer.active ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: menuLayer.active ? 120 : 90

                    easing.type: Easing.OutCubic
                }
            }

            Glass {
                anchors.fill: parent

                radius: parent.radius
            }

            Column {
                id: menuColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                anchors.margins: 5

                spacing: 1

                Repeater {
                    model: menuLayer.items

                    delegate: Loader {
                        id: entryLoader

                        required property var modelData

                        width: menuColumn.width

                        sourceComponent: entryLoader.modelData.separator === true ? separatorComp : entryComp

                        Component {
                            id: separatorComp

                            Item {
                                height: 7

                                Rectangle {
                                    anchors.centerIn: parent

                                    width: parent.width - 12
                                    height: 1

                                    color: Core.Theme.separator
                                }
                            }
                        }

                        Component {
                            id: entryComp

                            Rectangle {
                                height: 30

                                radius: Core.Theme.radiusRow

                                color: "transparent"

                                Tactile {
                                    anchors.fill: parent
                                    radius: Core.Theme.radiusRow
                                    hovered: entryMouse.containsMouse
                                    pressed: entryMouse.pressed
                                    hoverScale: 1.03
                                    pressScale: 0.94
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter

                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10

                                    spacing: 9

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter

                                        width: 16

                                        text: entryLoader.modelData.icon ? entryLoader.modelData.icon : ""

                                        font.family: Core.Theme.iconFont

                                        font.pixelSize: Core.Theme.iconSizeSmall

                                        color: entryLoader.modelData.danger === true ? Core.Theme.danger : Core.Theme.foregroundMuted
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: entryLoader.modelData.label

                                        font.family: Core.Theme.fontFamily

                                        font.pixelSize: Core.Theme.fontSize

                                        color: entryLoader.modelData.danger === true ? Core.Theme.danger : Core.Theme.foreground
                                    }
                                }

                                MouseArea {
                                    id: entryMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        const act = entryLoader.modelData.action;

                                        menuLayer.close();

                                        if (typeof act === "function")
                                            act();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
