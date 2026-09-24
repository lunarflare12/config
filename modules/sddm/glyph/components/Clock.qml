import QtQuick 2.15

Item {
    id: root
    width: 900
    height: 220

    property string fontName: "sans-serif"
    property color textColor: "white"
    property string symbolFontName: "sans-serif"

    property string timeStr: "00:00"
    property string dateStr: ""

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeStr
            font.family: root.fontName
            font.pixelSize: 108
            font.weight: Font.Light
            color: root.textColor
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateStr
            font.family: root.fontName
            font.pixelSize: 24
            color: root.textColor
            opacity: 0.9
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var date = new Date();
            var hours = date.getHours();
            var minutes = date.getMinutes();
            if (config.use24HourClock === "true") {
                var hStr = hours < 10 ? "0" + hours : "" + hours;
                var mStr = minutes < 10 ? "0" + minutes : "" + minutes;
                root.timeStr = hStr + ":" + mStr;
            } else {
                var ap = hours >= 12 ? "PM" : "AM";
                hours = hours % 12;
                if (hours === 0)
                    hours = 12;
                var mStr12 = minutes < 10 ? "0" + minutes : "" + minutes;
                root.timeStr = hours + ":" + mStr12;
            }
            root.dateStr = Qt.formatDate(date, "dddd, d MMMM");
        }
    }
}
