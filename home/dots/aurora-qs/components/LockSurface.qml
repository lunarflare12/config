import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../core" as Core

WlSessionLockSurface {
    id: surface

    required property var session

    color: "black"

    // Same asset SDDM glyph uses — not the live desktop wallpaper.
    readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.config/hyprlock/images/background.jpg"
    readonly property string avatar: "file://" + Quickshell.env("HOME") + "/.config/hyprlock/images/avatar.jpg"
    readonly property string fontName: Core.Theme.fontFamily
    readonly property color textColor: "white"
    readonly property color accentColor: "#0A84FF"
    readonly property color powerColor: "#D71921"
    readonly property string sessionName: {
        const raw = Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP") || "Hyprland";
        return String(raw).split(":")[0].replace(/[-_]/g, " ").toUpperCase();
    }

    FocusScope {
        id: root
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => surface.session.handleKey(event)

        Image {
            id: bg
            anchors.fill: parent
            source: surface.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: surface.session.inputOpen ? 0.42 : 0.12

            Behavior on opacity {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: surface.session.revealInput()
        }

        Column {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 72
            spacing: 4
            opacity: surface.session.inputOpen ? 0.55 : 1.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const d = clock.date;
                    let h = d.getHours() % 12;
                    if (h === 0)
                        h = 12;
                    const m = d.getMinutes();
                    return h + ":" + (m < 10 ? "0" : "") + m;
                }
                color: surface.textColor
                font.family: surface.fontName
                font.pixelSize: 108
                font.weight: Font.Light
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, "dddd, d MMMM")
                color: surface.textColor
                opacity: 0.9
                font.family: surface.fontName
                font.pixelSize: 24
            }
        }

        Item {
            id: loginPanel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 90
            width: 400
            height: 400
            opacity: surface.session.inputOpen ? 1 : 0
            scale: surface.session.inputOpen ? 1 : 0.96
            transformOrigin: Item.Bottom
            visible: opacity > 0.01
            enabled: surface.session.inputOpen
            property real slide: surface.session.inputOpen ? 0 : 1
            transform: Translate {
                y: loginPanel.slide * 360
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 560
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on slide {
                NumberAnimation {
                    duration: 560
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: card
                width: 340
                height: 300
                x: (loginPanel.width - width) / 2 + card.shakeX
                y: (loginPanel.height - height) / 2
                color: "transparent"

                property real shakeX: 0

                SequentialAnimation {
                    id: shake
                    NumberAnimation {
                        target: card
                        property: "shakeX"
                        to: -8
                        duration: 40
                    }
                    NumberAnimation {
                        target: card
                        property: "shakeX"
                        to: 8
                        duration: 40
                    }
                    NumberAnimation {
                        target: card
                        property: "shakeX"
                        to: -8
                        duration: 40
                    }
                    NumberAnimation {
                        target: card
                        property: "shakeX"
                        to: 8
                        duration: 40
                    }
                    NumberAnimation {
                        target: card
                        property: "shakeX"
                        to: 0
                        duration: 40
                    }
                }

                Connections {
                    target: surface.session
                    function onFailTickChanged() {
                        shake.start();
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20

                    Item {
                        Layout.preferredWidth: 280
                        Layout.preferredHeight: 70
                        Layout.alignment: Qt.AlignHCenter

                        Row {
                            anchors.centerIn: parent
                            spacing: 15

                            Item {
                                width: 54
                                height: 54

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 27
                                    color: Qt.rgba(255, 255, 255, 0.08)
                                    border.color: Qt.rgba(255, 255, 255, 0.25)
                                    border.width: 1.5

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: 3
                                        text: (surface.session.userName || "?").charAt(0).toUpperCase()
                                        color: surface.textColor
                                        font.pixelSize: 26
                                        font.family: surface.fontName
                                        visible: avatarImage.status !== Image.Ready
                                    }
                                }

                                Canvas {
                                    id: avatarCanvas
                                    anchors.fill: parent
                                    visible: avatarImage.status === Image.Ready

                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.beginPath();
                                        ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI);
                                        ctx.closePath();
                                        ctx.clip();
                                        ctx.drawImage(avatarImage, 0, 0, width, height);
                                    }
                                }

                                Image {
                                    id: avatarImage
                                    source: surface.avatar
                                    width: 54
                                    height: 54
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                    asynchronous: true
                                    onStatusChanged: if (status === Image.Ready)
                                        avatarCanvas.requestPaint()
                                }
                            }

                            Text {
                                text: surface.session.userName
                                color: surface.textColor
                                font.pixelSize: 18
                                font.family: surface.fontName
                            }

                            Text {
                                text: "▾"
                                color: surface.textColor
                                font.pixelSize: 14
                                opacity: 0.5
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 280
                        Layout.preferredHeight: 50
                        Layout.alignment: Qt.AlignHCenter

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(255, 255, 255, 0.18)
                            radius: 18
                            border.color: surface.session.showFailure ? surface.accentColor : (surface.session.inputOpen ? surface.accentColor : Qt.rgba(255, 255, 255, 0.28))
                            border.width: 1
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: surface.session.currentText.length === 0
                            text: surface.session.showFailure ? "Incorrect password" : "Enter Password"
                            color: surface.session.showFailure ? "#FF453A" : Qt.rgba(255, 255, 255, 0.5)
                            font.family: surface.fontName
                            font.pixelSize: 14
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: surface.session.currentText.length > 0
                            text: "•".repeat(Math.min(24, surface.session.currentText.length))
                            color: surface.textColor
                            font.family: surface.fontName
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    RowLayout {
                        Layout.preferredWidth: 280
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 15

                        Rectangle {
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 40
                            color: Qt.rgba(255, 255, 255, 0.05)
                            radius: 20
                            border.color: Qt.rgba(255, 255, 255, 0.15)

                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: surface.sessionName
                                    font.family: surface.fontName
                                    font.pixelSize: 12
                                    color: surface.textColor
                                    opacity: 0.7
                                }

                                Text {
                                    text: "▾"
                                    color: surface.textColor
                                    font.pixelSize: 10
                                    opacity: 0.4
                                }
                            }
                        }

                        Rectangle {
                            id: loginButton
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 50
                            radius: 25
                            color: surface.session.unlocking ? Qt.rgba(255, 255, 255, 0.1) : surface.accentColor
                            scale: loginClick.pressed ? 0.9 : 1.0

                            Text {
                                anchors.centerIn: parent
                                text: surface.session.unlocking ? "⋯" : "→"
                                color: "white"
                                font.pixelSize: 28
                            }

                            MouseArea {
                                id: loginClick
                                anchors.fill: parent
                                enabled: !surface.session.unlocking
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (surface.session.currentText.length === 0) {
                                        surface.session.failAttempt();
                                        return;
                                    }
                                    surface.session.tryUnlock();
                                }
                            }
                        }
                    }
                }
            }
        }

        Row {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 50
            spacing: 20
            opacity: surface.session.inputOpen ? 0.55 : 1.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: [
                    {
                        glyph: Core.Icons.sleep,
                        size: 48,
                        icon: 20,
                        color: Qt.rgba(0, 0, 0, 0.7),
                        border: true,
                        command: ["systemctl", "suspend"]
                    },
                    {
                        glyph: Core.Icons.refresh,
                        size: 48,
                        icon: 20,
                        color: Qt.rgba(0, 0, 0, 0.7),
                        border: true,
                        command: ["systemctl", "reboot"]
                    },
                    {
                        glyph: Core.Icons.power,
                        size: 60,
                        icon: 24,
                        color: surface.powerColor,
                        border: false,
                        command: ["systemctl", "poweroff"]
                    }
                ]

                Rectangle {
                    required property var modelData
                    width: modelData.size
                    height: modelData.size
                    radius: modelData.size / 2
                    color: modelData.color
                    border.color: modelData.border ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                    border.width: modelData.border ? 1 : 0

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.glyph
                        font.family: Core.Theme.iconFont
                        font.pixelSize: parent.modelData.icon
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(parent.modelData.command)
                    }
                }
            }
        }
    }
}
