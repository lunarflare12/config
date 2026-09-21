import QtQuick
import "../services" as Services

// macOS-style folder tile: rounded well with a 2×2 of app icons.
Item {
    id: root

    property var apps: []
    property int well: Math.round(Math.min(width, height) * 0.92)
    property int glyph: Math.round(root.well * 0.34)
    property int gap: Math.max(2, Math.round(root.well * 0.06))

    Rectangle {
        id: plate
        anchors.centerIn: parent
        width: root.well
        height: root.well
        radius: Math.round(root.well * 0.24)
        color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.28)
        antialiasing: true
    }

    Grid {
        anchors.centerIn: plate
        columns: 2
        rows: 2
        spacing: root.gap

        Repeater {
            model: 4

            Item {
                required property int index
                width: root.glyph
                height: root.glyph

                readonly property var entry: {
                    const list = root.apps || [];
                    return index < list.length ? list[index] : null;
                }

                Image {
                    anchors.fill: parent
                    visible: parent.entry !== null
                    source: parent.entry ? Services.AppsService.iconSource(parent.entry) : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    cache: true
                    sourceSize.width: 64
                    sourceSize.height: 64
                }
            }
        }
    }
}
