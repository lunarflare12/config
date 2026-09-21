import QtQuick

import "../core" as Core

Item {
    id: root

    property string kind: "app"
    property string icon: ""
    property string title: "App"
    property bool playing: false
    readonly property bool browser: root.kind === "browser"

    component Bone: Rectangle {
        property real delay: 0
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.09)
        SequentialAnimation on opacity {
            running: root.playing
            loops: Animation.Infinite
            PauseAnimation {
                duration: delay
            }
            NumberAnimation {
                from: 0.45
                to: 1
                duration: 780
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 1
                to: 0.45
                duration: 780
                easing.type: Easing.InOutSine
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Core.Theme.background
        border.width: 4
        border.color: Core.Theme.borderActive
    }

    Item {
        id: chrome
        anchors.fill: parent
        anchors.margins: 4
        clip: true

        Rectangle {
            id: titlebar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 42
            color: Qt.rgba(1, 1, 1, 0.03)

            Image {
                id: pix
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: root.icon
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                smooth: true
                visible: root.icon !== "" && status === Image.Ready
            }

            Bone {
                anchors.left: pix.visible ? pix.right : parent.left
                anchors.leftMargin: pix.visible ? 10 : 14
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(220, parent.width * 0.28)
                height: 11
                delay: 0
            }
        }

        Item {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titlebar.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 18
            anchors.topMargin: root.browser ? 14 : 22

            Row {
                id: tabs
                visible: root.browser
                spacing: 8
                height: 28

                Repeater {
                    model: 3
                    Bone {
                        required property int index
                        width: 92 - index * 10
                        height: 22
                        delay: index * 80
                    }
                }
            }

            Bone {
                id: url
                visible: root.browser
                anchors.top: tabs.bottom
                anchors.topMargin: 12
                width: parent.width
                height: 32
                radius: 10
                delay: 120
            }

            Column {
                anchors.top: root.browser ? url.bottom : parent.top
                anchors.topMargin: root.browser ? 22 : 0
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 14

                Bone {
                    width: parent.width * 0.42
                    height: 16
                    delay: 40
                }
                Bone {
                    width: parent.width * 0.72
                    height: 12
                    delay: 120
                }
                Bone {
                    width: parent.width * 0.58
                    height: 12
                    delay: 200
                }
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 16
                height: Math.min(220, parent.height * 0.42)

                Repeater {
                    model: 2
                    Bone {
                        required property int index
                        width: (parent.width - 16) / 2
                        height: parent.height
                        radius: 12
                        delay: 160 + index * 90
                    }
                }
            }
        }

        Rectangle {
            id: shimmer
            width: Math.min(220, parent.width * 0.28)
            height: parent.height
            x: -width
            opacity: 0.14
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: "#ffffff"
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }

            SequentialAnimation on x {
                running: root.playing
                loops: Animation.Infinite
                NumberAnimation {
                    from: -shimmer.width
                    to: chrome.width
                    duration: 1300
                    easing.type: Easing.InOutCubic
                }
                PauseAnimation {
                    duration: 380
                }
            }
        }
    }
}
