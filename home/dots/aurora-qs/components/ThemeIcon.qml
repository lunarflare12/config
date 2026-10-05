import QtQuick

import "../core" as Core

// Bar glyphs via Nerd Font (same stack as Vpn.qml). Brand marks without a
// font codepoint still use the SVG assets (nix / arch / …).
Item {
    id: root

    property string name: ""
    property color color: Core.Theme.text

    width: Core.Theme.iconSize
    height: Core.Theme.iconSize

    readonly property string glyph: Core.Icons.barGlyph(root.name)
    readonly property bool useFont: root.glyph !== ""

    Text {
        id: fontGlyph
        anchors.centerIn: parent
        visible: root.useFont
        text: root.glyph
        color: root.color
        font.family: Core.Theme.iconFont
        font.pixelSize: Math.round(Math.min(root.width, root.height) * 1.05)
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.QtRendering
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        transformOrigin: Item.Center
    }

    Image {
        id: mark
        anchors.centerIn: parent
        visible: !root.useFont && root.name !== ""
        width: root.width
        height: root.height
        source: !root.useFont && root.name !== "" ? Qt.resolvedUrl("../assets/bar/" + root.name + ".svg") : ""
        sourceSize.width: Math.max(64, Math.round(root.width) * 4)
        sourceSize.height: Math.max(64, Math.round(root.height) * 4)
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        cache: true
        smooth: true
        mipmap: false
        antialiasing: true
        transformOrigin: Item.Center
    }
}
