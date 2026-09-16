import QtQuick

import Quickshell

import "../core" as Core
import "../services" as Services
import "../components" as Components

Components.PopupSurface {
    id: popup

    popupId: "brightness"
    cardWidth: 350
    maxCardHeight: 520

    readonly property var svc: Services.BrightnessService

    contentComponent: Component {
        Column {
            id: body
            spacing: Core.Theme.spacing

            Components.PopupHeader {
                width: parent.width
                title: "Brightness"
                subtitle: popup.svc.displayList.length > 1 ? "Choose a display" : popup.svc.selectedLabel
                showToggle: false
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Core.Theme.separator
            }

            Repeater {
                model: popup.svc.displayList

                delegate: Rectangle {
                    id: card

                    required property var modelData

                    readonly property string monName: String(card.modelData.name || "")
                    readonly property string monLabel: String(card.modelData.label || card.monName)
                    readonly property int monPercent: {
                        const _ = popup.svc.levels;
                        return popup.svc.percentOf(card.monName);
                    }
                    readonly property bool monActive: popup.svc.selectedName === card.monName
                    readonly property bool monDdc: String(card.modelData.backend) === "ddc"

                    width: body.width
                    height: 96
                    radius: Core.Theme.radiusRow
                    color: card.monActive ? Qt.alpha(Core.Theme.accent, 0.12) : Core.Theme.surfaceGlass

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 20

                            Components.ThemeIcon {
                                id: sun
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                name: Core.Icons.brightnessTheme(card.monPercent / 100)
                            }

                            Text {
                                anchors.left: sun.right
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.monLabel
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: Core.Theme.fontSize
                                font.weight: card.monActive ? Font.DemiBold : Font.Medium
                                color: Core.Theme.foreground
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.monPercent + "%"
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: Core.Theme.fontSizeLarge
                                font.weight: Font.DemiBold
                                color: Core.Theme.foreground
                            }
                        }

                        Text {
                            text: card.monName + " · " + (card.monDdc ? "Hardware" : "Software")
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: Core.Theme.fontSizeSmall
                            color: Core.Theme.foregroundMuted
                        }

                        Components.VolumeSlider {
                            width: parent.width
                            value: card.monPercent / 100
                            fillColor: Core.Theme.accent
                            onMoved: function (v) {
                                popup.svc.dragging = true;
                                popup.svc.select(card.monName);
                                popup.svc.setDisplayPercent(card.monName, v * 100, false);
                            }
                            onReleased: function (v) {
                                popup.svc.setDisplayPercent(card.monName, v * 100, true);
                            }
                        }
                    }

                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 40
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.svc.select(card.monName)
                    }
                }
            }

            Item {
                width: parent.width
                height: popup.svc.displayList.length > 0 ? 0 : 70
                visible: height > 0

                Text {
                    anchors.centerIn: parent
                    text: "No displays"
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: Core.Theme.fontSizeSmall
                    color: Core.Theme.foregroundMuted
                }
            }
        }
    }
}
