import QtQuick

import "../core" as Core

Image {
    id: root

    property string name: ""

    width: Core.Theme.iconSize
    height: Core.Theme.iconSize
    source: root.name !== "" ? Qt.resolvedUrl("../assets/bar/" + root.name + ".svg") : ""
    sourceSize.width: 64
    sourceSize.height: 64
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    // Off so bar SVG edits show up without a full Quickshell restart.
    cache: false
    smooth: true
    mipmap: true
    transformOrigin: Item.Center
}
