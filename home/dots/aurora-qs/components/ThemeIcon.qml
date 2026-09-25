import QtQuick

import "../core" as Core

Image {
    id: root

    property string name: ""

    width: Core.Theme.iconSize
    height: Core.Theme.iconSize
    source: root.name !== "" ? Qt.resolvedUrl("../assets/bar/" + root.name + ".svg") : ""
    // Rasterize at the pixel size on screen. 64→17 with smooth was the muddy bar.
    sourceSize.width: Math.max(1, Math.round(width))
    sourceSize.height: Math.max(1, Math.round(height))
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: false
    mipmap: false
    antialiasing: true
    transformOrigin: Item.Center
}
