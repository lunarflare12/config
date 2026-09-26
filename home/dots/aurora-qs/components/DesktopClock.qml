import QtQuick
import Quickshell

import "../core" as Core

// Wallpaper clock: big weekday, date, 12-hour time. Size follows the text.
Item {
    id: root

    property var modelData: null
    property var host: parent

    readonly property string monitorName: host && host.monitorName ? host.monitorName : ""
    readonly property bool onDesktop: Core.Session.widgetsOnMonitor(root.monitorName)

    anchors.fill: parent
    visible: root.onDesktop

    FontLoader {
        id: displayFont
        source: Qt.resolvedUrl("../assets/fonts/Anurati-Regular.otf")
    }

    DesktopWidget {
        host: root.host
        widgetId: "clock"
        onDesktop: root.onDesktop
        framed: false
        fitContent: true
        spanW: 5
        spanH: 2
        defaultCol: 1
        defaultRow: 0
        contentComponent: clockContent
    }

    Component {
        id: clockContent

        Column {
            id: clock

            spacing: 10

            readonly property string displayFamily: displayFont.status === FontLoader.Ready ? (displayFont.name || displayFont.font.family) : Core.Theme.fontFamily
            readonly property color ink: "#F4F7FB"
            readonly property color shade: "#66081428"

            SystemClock {
                id: now
                precision: SystemClock.Minutes
            }

            readonly property var months: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
            readonly property var weekdays: ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]

            function pad2(n) {
                return n < 10 ? "0" + n : "" + n;
            }

            readonly property string weekday: clock.weekdays[now.date.getDay()]
            readonly property string dateLine: {
                const d = now.date;
                return clock.pad2(d.getDate()) + " " + clock.months[d.getMonth()] + " " + d.getFullYear();
            }
            readonly property string timeLine: {
                const d = now.date;
                const h24 = d.getHours();
                const h12 = h24 % 12 || 12;
                const ap = h24 < 12 ? "AM" : "PM";
                return "-  " + clock.pad2(h12) + ":" + clock.pad2(d.getMinutes()) + " " + ap + "  -";
            }

            Item {
                id: dayBox
                implicitWidth: dayLabel.implicitWidth
                implicitHeight: dayLabel.implicitHeight + 3
                width: implicitWidth
                height: implicitHeight

                Text {
                    id: dayShade
                    anchors.fill: dayLabel
                    anchors.topMargin: 3
                    text: dayLabel.text
                    color: clock.shade
                    font: dayLabel.font
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }

                Text {
                    id: dayLabel
                    text: clock.weekday
                    color: clock.ink
                    horizontalAlignment: Text.AlignHCenter
                    font.family: clock.displayFamily
                    font.pixelSize: 72
                    font.letterSpacing: 8
                    font.weight: Font.Normal
                    renderType: Text.NativeRendering
                }
            }

            Item {
                id: dateBox
                implicitWidth: dateLabel.implicitWidth
                implicitHeight: dateLabel.implicitHeight + 2
                width: Math.max(implicitWidth, dayBox.implicitWidth)
                height: implicitHeight

                Text {
                    id: dateShade
                    anchors.fill: dateLabel
                    anchors.topMargin: 2
                    text: dateLabel.text
                    color: clock.shade
                    font: dateLabel.font
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }

                Text {
                    id: dateLabel
                    width: parent.width
                    text: clock.dateLine
                    color: clock.ink
                    horizontalAlignment: Text.AlignHCenter
                    font.family: clock.displayFamily
                    font.pixelSize: 22
                    font.letterSpacing: 6
                    renderType: Text.NativeRendering
                }
            }

            Item {
                id: timeBox
                implicitWidth: timeLabel.implicitWidth
                implicitHeight: timeLabel.implicitHeight + 1
                width: Math.max(implicitWidth, dayBox.implicitWidth)
                height: implicitHeight

                Text {
                    id: timeShade
                    anchors.fill: timeLabel
                    anchors.topMargin: 1
                    text: timeLabel.text
                    color: clock.shade
                    font: timeLabel.font
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }

                Text {
                    id: timeLabel
                    width: parent.width
                    text: clock.timeLine
                    color: Qt.rgba(clock.ink.r, clock.ink.g, clock.ink.b, 0.82)
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 14
                    font.letterSpacing: 6
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
